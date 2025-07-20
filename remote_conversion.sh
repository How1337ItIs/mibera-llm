#!/bin/bash
# remote_conversion.sh - Complete Mibera conversion with FFN splitting
# Run this on vast.ai instance with sufficient disk space

set -e
echo "=== MIBERA REMOTE CONVERSION WITH FFN SPLITTING ==="

# Setup environment
echo "[1/7] Setting up environment..."
apt update -y && apt install -y git python3 python3-pip cmake build-essential
pip3 install torch transformers huggingface-hub safetensors accelerate sentencepiece protobuf numpy gguf

# Clone llama.cpp
echo "[2/7] Cloning llama.cpp..."
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# Apply FFN splitting patch to convert_hf_to_gguf.py
echo "[3/7] Applying FFN splitting patch..."
cp convert_hf_to_gguf.py convert_hf_to_gguf.py.orig

# Insert FFN splitting code into the convert script
cat > ffn_patch.py << 'EOF'
import sys
import re

# Read the original file
with open('convert_hf_to_gguf.py', 'r') as f:
    content = f.read()

# Find the write_tensors method in the Phi3Model class
# Look for the pattern where tensors are processed
pattern = r'(def write_tensors\(self\):[^}]+?)(\s+return tensors)'

# FFN splitting code to insert
ffn_split_code = '''
        # ----- MIBERA CUSTOM: handle fused (gate+up) FFN weight -----
        # Expected: separate gate & up matrices each (n_embd, ffn_dim)  
        # Actual fused: single matrix (n_embd, 2*ffn_dim) stored as ffn_up.weight
        if name.endswith("ffn_up.weight"):
            # Sanity checks
            if data_torch.ndim != 2:
                raise ValueError(f"Unexpected fused FFN rank: {name} shape={tuple(data_torch.shape)}")
            
            in_dim, out_dim = data_torch.shape  # typically (n_embd, 2*ffn_dim)
            
            # Determine which axis is doubled (expect doubling on the 'out' dimension)
            if out_dim % 2 == 0:
                half = out_dim // 2
                W_gate = data_torch[:, :half].contiguous()
                W_up   = data_torch[:, half:].contiguous()
                split_axis = 1
            elif in_dim % 2 == 0:
                # Unlikely here, but included for robustness
                half = in_dim // 2
                W_gate = data_torch[:half, :].contiguous()
                W_up   = data_torch[half:, :].contiguous()
                split_axis = 0
            else:
                raise ValueError(f"Cannot infer fused FFN split for {name} shape={tuple(data_torch.shape)}")
            
            # Debug output
            print(f"[phi3 split] {name}: fused {data_torch.shape} -> gate {W_gate.shape} + up {W_up.shape} (axis {split_axis})")
            
            # Heuristic ordering: assume FIRST half = gate (activation), SECOND = up (value)
            # If generations look degraded, invert the assignment above (swap W_gate and W_up)
            
            # Write tensors with names expected by llama.cpp phi3 loader
            gate_name = new_name.replace("ffn_up.weight", "ffn_gate.weight")
            up_name = new_name  # Keep original name for up
            
            tensors.append((gate_name, W_gate))
            tensors.append((up_name, W_up))
            
        else:
            # Regular tensor processing
            tensors.append((new_name, data_torch))'''

# Find the location to insert the FFN splitting code - more precise targeting
# Look for the specific pattern where tensors are added
insert_pattern = r'(\s+new_name = self\.map_tensor_name\(name\)\s+)(tensors\.append\(\(new_name, data_torch\)\))'

replacement = ffn_split_code

# Apply the patch - replace the generic append with our conditional logic
modified_content = re.sub(insert_pattern, replacement, content, flags=re.DOTALL)

# Write the modified file
with open('convert_hf_to_gguf.py', 'w') as f:
    f.write(modified_content)

print("FFN splitting patch applied successfully")
EOF

python3 ffn_patch.py

# Build llama.cpp
echo "[4/7] Building llama.cpp..."
mkdir build && cd build
cmake .. -DLLAMA_BUILD_TESTS=OFF
make -j$(nproc)
cd ..

# Create working directories
echo "[5/7] Setting up workspace..."
mkdir -p /workspace/mibera/output
cd /workspace/mibera

# Fix model config for Phi3 compatibility
echo "[6/7] Converting model with FFN splitting..."
export HF_HUB_CACHE=/workspace/cache

# First fix the config by downloading and modifying
python3 -c "
import json
from huggingface_hub import hf_hub_download

# Download and fix config
config_path = hf_hub_download('ivxxdegen/mibera-v1-merged', 'config.json')
with open(config_path, 'r') as f:
    config = json.load(f)

# Fix config for Phi2 compatibility (matches working loader patches)
config.update({
    'architectures': ['PhiForCausalLM'],
    'model_type': 'phi',
    'num_hidden_layers': 40,
    'num_attention_heads': 32,
    'hidden_size': 5120,
    'vocab_size': 100352,
    'intermediate_size': 17920
})

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)
print('Config fixed for Phi2 compatibility (matches loader patches)')
"

# Convert with FFN splitting
python3 /workspace/mibera/llama.cpp/convert_hf_to_gguf.py \
    --remote ivxxdegen/mibera-v1-merged \
    --outfile /workspace/mibera/output/mibera-f16-split.gguf \
    --outtype f16 \
    --verbose

# Verify FFN splitting worked before quantization
echo "=== PRE-QUANTIZATION VERIFICATION ==="
python3 -c "
from gguf import GGUFReader
import sys

try:
    reader = GGUFReader('/workspace/mibera/output/mibera-f16-split.gguf')
    tensor_names = [t.name for t in reader.tensors]
    total = len(tensor_names)
    gate_count = len([n for n in tensor_names if 'ffn_gate.weight' in n])
    up_count = len([n for n in tensor_names if 'ffn_up.weight' in n and 'gate' not in n])
    
    print(f'F16 model verification:')
    print(f'  Total tensors: {total}')
    print(f'  FFN gate tensors: {gate_count}')
    print(f'  FFN up tensors: {up_count}')
    success = (total == 243 and gate_count == 40 and up_count == 40)
    print(f'  Pre-quant success: {success}')
    
    if not success:
        print('ERROR: FFN splitting failed - aborting quantization')
        sys.exit(1)
    else:
        print('✅ FFN splitting confirmed - proceeding to quantization')
        
except Exception as e:
    print(f'Error verifying F16 model: {e}')
    sys.exit(1)
"

echo "[7/7] Quantizing to Q3_K_M and Q4_K_M..."
cd /workspace/mibera/output

# Quantize to recommended formats
/workspace/mibera/llama.cpp/build/bin/llama-quantize \
    mibera-f16-split.gguf \
    mibera-Q3_K_M-split.gguf \
    Q3_K_M

/workspace/mibera/llama.cpp/build/bin/llama-quantize \
    mibera-f16-split.gguf \
    mibera-Q4_K_M-split.gguf \
    Q4_K_M

# Verify tensor count
echo "=== VERIFICATION ==="
python3 -c "
from gguf import GGUFReader
import sys

for model in ['mibera-Q3_K_M-split.gguf', 'mibera-Q4_K_M-split.gguf']:
    try:
        reader = GGUFReader(model)
        tensor_names = [t.name for t in reader.tensors]
        total = len(tensor_names)
        gate_count = len([n for n in tensor_names if 'ffn_gate.weight' in n])
        up_count = len([n for n in tensor_names if 'ffn_up.weight' in n and 'gate' not in n])
        
        print(f'{model}:')
        print(f'  Total tensors: {total}')
        print(f'  FFN gate tensors: {gate_count}')
        print(f'  FFN up tensors: {up_count}')
        print(f'  Success: {total == 243 and gate_count == 40 and up_count == 40}')
        print()
    except Exception as e:
        print(f'Error reading {model}: {e}')
"

# Generate checksums
sha256sum *.gguf > SHA256SUMS-$(date +%Y-%m-%d).txt

echo ""
echo "=== CONVERSION COMPLETE ==="
echo "Files created:"
ls -lh /workspace/mibera/output/
echo ""
echo "Ready for download!"
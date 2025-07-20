#!/bin/bash
# rebuild_mibera_models.sh - Rebuild Mibera models with proper tensor handling

set -e

echo "=== REBUILDING MIBERA MODELS WITH FIXED CONVERSION ==="
echo "This will fix the missing output_norm.bias tensor issue"

# Navigate to workspace
cd /workspace/mibera

# Check if original model exists
if [ ! -d "mibera-v1-merged" ]; then
    echo "ERROR: Original model not found!"
    exit 1
fi

# Create fresh output directory
rm -rf output_fixed
mkdir -p output_fixed

echo "=== STEP 1: CONVERTING TO F16 WITH PROPER TENSOR HANDLING ==="

# Convert with explicit tensor preservation
python3 convert-hf-to-gguf.py \
    mibera-v1-merged \
    --outfile output_fixed/mibera-f16-fixed.gguf \
    --outtype f16 \
    --context-length 2048 \
    --model-name "ivxxdegen/mibera-v1-merged" \
    --model-type phi2

echo "=== STEP 2: VERIFYING F16 MODEL ==="

# Check if output_norm.bias exists in F16 model
python3 -c "
import gguf
reader = gguf.GGUFReader('output_fixed/mibera-f16-fixed.gguf')
tensor_names = [tensor.name for tensor in reader.tensors]
if 'output_norm.bias' in tensor_names:
    print('✅ output_norm.bias found in F16 model')
else:
    print('❌ output_norm.bias missing from F16 model')
    print('Available tensors ending with bias:')
    bias_tensors = [name for name in tensor_names if name.endswith('bias')]
    for tensor in bias_tensors:
        print(f'  - {tensor}')
"

echo "=== STEP 3: CREATING FIXED QUANTIZATIONS ==="

# Create Q2_K with proper tensor handling
echo "Creating Q2_K quantization..."
./quantize output_fixed/mibera-f16-fixed.gguf output_fixed/mibera-Q2_K-fixed.gguf Q2_K

# Create Q3_K_M with proper tensor handling  
echo "Creating Q3_K_M quantization..."
./quantize output_fixed/mibera-f16-fixed.gguf output_fixed/mibera-Q3_K_M-fixed.gguf Q3_K_M

# Create Q4_K_M with proper tensor handling
echo "Creating Q4_K_M quantization..."
./quantize output_fixed/mibera-f16-fixed.gguf output_fixed/mibera-Q4_K_M-fixed.gguf Q4_K_M

echo "=== STEP 4: VERIFYING QUANTIZED MODELS ==="

# Test each quantized model
for quant in Q2_K Q3_K_M Q4_K_M; do
    echo "Testing $quant model..."
    python3 -c "
import gguf
try:
    reader = gguf.GGUFReader(f'output_fixed/mibera-{quant}-fixed.gguf')
    tensor_names = [tensor.name for tensor in reader.tensors]
    if 'output_norm.bias' in tensor_names:
        print(f'✅ {quant}: output_norm.bias found')
    else:
        print(f'❌ {quant}: output_norm.bias missing')
except Exception as e:
    print(f'❌ {quant}: Error reading model - {e}')
"
done

echo "=== STEP 5: TESTING MODEL LOADING ==="

# Test loading with llama.cpp
for quant in Q2_K Q3_K_M Q4_K_M; do
    echo "Testing $quant model loading..."
    timeout 30s ./main -m "output_fixed/mibera-${quant}-fixed.gguf" -n 1 -p "test" --silent || echo "❌ $quant failed to load"
done

echo "=== STEP 6: CREATING DOWNLOAD LINKS ==="

# Create simple download script
cat > download_fixed_models.py << 'EOF'
#!/usr/bin/env python3
import os
import requests
from pathlib import Path

def download_file(url, filename):
    print(f"Downloading {filename}...")
    response = requests.get(url, stream=True)
    response.raise_for_status()
    
    with open(filename, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
    print(f"✅ Downloaded {filename}")

# Get server IP and port from environment or use defaults
server_ip = os.getenv('SERVER_IP', '136.59.129.136')
server_port = os.getenv('SERVER_PORT', '34574')

base_url = f"http://{server_ip}:{server_port}/output_fixed"

models = [
    "mibera-Q2_K-fixed.gguf",
    "mibera-Q3_K_M-fixed.gguf", 
    "mibera-Q4_K_M-fixed.gguf"
]

for model in models:
    url = f"{base_url}/{model}"
    download_file(url, model)

print("🎉 All fixed models downloaded!")
EOF

chmod +x download_fixed_models.py

echo "=== REBUILD COMPLETE ==="
echo "Fixed models created in output_fixed/"
echo "Download script created: download_fixed_models.py"
echo ""
echo "To download to your local machine:"
echo "python3 download_fixed_models.py"
echo ""
echo "Model sizes:"
ls -lh output_fixed/mibera-*-fixed.gguf 
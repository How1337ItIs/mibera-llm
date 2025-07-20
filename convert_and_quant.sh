#!/usr/bin/env bash
# One-click reconversion and quantization script
# Based on O3's recommendations

set -euo pipefail

MODEL_DIR=/workspace/mibera/models/mibera
OUT=/workspace/mibera/output
LLAMA_PATH=/workspace/llama.cpp

echo "=== MIBERA CONVERSION WITH CORRECTED ARCHITECTURE ==="
echo "Target: 40 layers, hidden 5120, vocab 100352"
echo ""

# Step 1: Verify architecture matches config
echo "Step 1: Verifying architecture..."
cd $MODEL_DIR
python3 -c "
import json, glob, safetensors, re
ckpt = sorted(glob.glob('model-*.safetensors'))[0]
with safetensors.safe_open(ckpt, framework='pt') as f:
    vocab, hidden = f.get_tensor('model.embed_tokens.weight').shape
    max_layer = max([int(re.search(r'layers\.(\d+)\.', k).group(1)) 
                     for k in f.keys() if 'layers.' in k])
    fused = any('qkv_proj' in k for k in f.keys())
print(f'Architecture: hidden={hidden}, vocab={vocab}, layers={max_layer+1}, fused_qkv={fused}')
cfg = json.load(open('config.json'))
assert cfg['hidden_size'] == hidden, f'hidden_size mismatch: {cfg[\"hidden_size\"]} != {hidden}'
assert cfg['vocab_size'] == vocab, f'vocab_size mismatch: {cfg[\"vocab_size\"]} != {vocab}'
assert cfg['num_hidden_layers'] == max_layer+1, f'layers mismatch: {cfg[\"num_hidden_layers\"]} != {max_layer+1}'
print('✓ All architecture parameters match!')
"

# Step 2: Convert to F16 (if not already done)
if [ ! -f "$OUT/mibera-f16-fixed.gguf" ]; then
    echo ""
    echo "Step 2: Converting to F16..."
    python3 $LLAMA_PATH/convert_hf_to_gguf.py $MODEL_DIR \
        --outfile $OUT/mibera-f16-fixed.gguf --outtype f16
else
    echo ""
    echo "Step 2: F16 already exists, skipping conversion"
fi

# Step 3: Quantize to multiple formats
echo ""
echo "Step 3: Quantizing models..."
cd $OUT

# Create quantized versions
for Q in Q3_K_M Q4_K_M Q5_K_M; do
    if [ ! -f "mibera-$Q-fixed.gguf" ]; then
        echo "  Creating $Q quantization..."
        $LLAMA_PATH/build/bin/llama-quantize mibera-f16-fixed.gguf mibera-$Q-fixed.gguf $Q
    else
        echo "  $Q already exists, skipping"
    fi
done

# Optional: Create Q2_K for extreme memory constraints
if [ "${CREATE_Q2K:-0}" = "1" ]; then
    echo "  Creating Q2_K quantization (minimal quality)..."
    $LLAMA_PATH/build/bin/llama-quantize mibera-f16-fixed.gguf mibera-Q2_K-fixed.gguf Q2_K
fi

# Step 4: Generate checksums
echo ""
echo "Step 4: Generating checksums..."
sha256sum mibera-*fixed.gguf > SHA256SUMS-$(date +%Y-%m-%d).txt
cat SHA256SUMS-$(date +%Y-%m-%d).txt

# Step 5: Quick validation
echo ""
echo "Step 5: Validating Q3_K_M model..."
$LLAMA_PATH/build/bin/llama-cli -m mibera-Q3_K_M-fixed.gguf \
    -p "Test." -n 10 --log-disable 2>&1 | grep -E "(n_layer|n_embd|n_vocab)" || true

echo ""
echo "=== CONVERSION COMPLETE ==="
echo "Files ready for download:"
ls -lh mibera-*fixed.gguf
echo ""
echo "Recommended for i3-1115G4 (12GB RAM):"
echo "  - Q3_K_M: Best speed/memory balance"
echo "  - Q4_K_M: Better quality if RAM allows"
echo "  - Q5_K_M: May require closing other apps"
#!/bin/bash
# convert_mibera.sh - Cloud conversion script for Mibera model
# Run this after uploading your model files

set -e
cd /workspace/mibera

echo "=== MIBERA CLOUD CONVERSION ==="
echo "Starting conversion process..."

# Check if model files exist
MODEL_DIR="models/mibera"
if [ ! -d "$MODEL_DIR" ]; then
    echo "ERROR: Model directory not found at $MODEL_DIR"
    echo "Please upload your model files first!"
    exit 1
fi

# Count safetensor files
SAFETENSOR_COUNT=$(find "$MODEL_DIR" -name "*.safetensors" | wc -l)
echo "Found $SAFETENSOR_COUNT safetensor files"

if [ "$SAFETENSOR_COUNT" -ne 13 ]; then
    echo "WARNING: Expected 13 safetensor files, found $SAFETENSOR_COUNT"
    echo "Continuing anyway..."
fi

# Display available disk space
echo "Disk space check:"
df -h /workspace

# Step 1: Convert to GGUF F16
echo ""
echo "[1/4] Converting to GGUF F16 format..."
python3 convert_hf_to_gguf.py "$MODEL_DIR" \
    --outfile "output/mibera-f16.gguf" \
    --outtype f16 \
    --verbose

if [ ! -f "output/mibera-f16.gguf" ]; then
    echo "ERROR: F16 conversion failed!"
    exit 1
fi

F16_SIZE=$(du -h output/mibera-f16.gguf | cut -f1)
echo "✓ F16 GGUF created: $F16_SIZE"

# Step 2: Create Q3_K_M quantization (recommended)
echo ""
echo "[2/4] Creating Q3_K_M quantization (recommended)..."
./llama-quantize output/mibera-f16.gguf output/mibera-Q3_K_M.gguf Q3_K_M

if [ -f "output/mibera-Q3_K_M.gguf" ]; then
    Q3_SIZE=$(du -h output/mibera-Q3_K_M.gguf | cut -f1)
    echo "✓ Q3_K_M created: $Q3_SIZE"
else
    echo "ERROR: Q3_K_M quantization failed!"
fi

# Step 3: Create Q2_K quantization (low RAM option)
echo ""
echo "[3/4] Creating Q2_K quantization (low RAM option)..."
./llama-quantize output/mibera-f16.gguf output/mibera-Q2_K.gguf Q2_K

if [ -f "output/mibera-Q2_K.gguf" ]; then
    Q2_SIZE=$(du -h output/mibera-Q2_K.gguf | cut -f1)
    echo "✓ Q2_K created: $Q2_SIZE"
else
    echo "WARNING: Q2_K quantization failed!"
fi

# Step 4: Create Q4_K_M quantization (high quality option)
echo ""
echo "[4/4] Creating Q4_K_M quantization (high quality option)..."
./llama-quantize output/mibera-f16.gguf output/mibera-Q4_K_M.gguf Q4_K_M

if [ -f "output/mibera-Q4_K_M.gguf" ]; then
    Q4_SIZE=$(du -h output/mibera-Q4_K_M.gguf | cut -f1)
    echo "✓ Q4_K_M created: $Q4_SIZE"
else
    echo "WARNING: Q4_K_M quantization failed!"
fi

# Clean up F16 to save space
echo ""
echo "Cleaning up intermediate F16 file..."
rm -f output/mibera-f16.gguf
echo "✓ F16 file removed to save space"

# Final summary
echo ""
echo "=== CONVERSION COMPLETE ==="
echo "Output files in /workspace/mibera/output/:"
ls -lh output/*.gguf 2>/dev/null || echo "No GGUF files found"

echo ""
echo "Download these files to your local machine:"
find output -name "*.gguf" -exec basename {} \;

echo ""
echo "Recommended for your 12GB RAM system: mibera-Q3_K_M.gguf"
echo "For emergency low RAM usage: mibera-Q2_K.gguf"
echo "For best quality (if RAM allows): mibera-Q4_K_M.gguf"

# Test one of the models
if [ -f "output/mibera-Q3_K_M.gguf" ]; then
    echo ""
    echo "Testing Q3_K_M model..."
    echo "Test prompt: 'Hello! Tell me about yourself.'"
    timeout 30s ./llama-cli -m output/mibera-Q3_K_M.gguf -n 50 -p "Hello! Tell me about yourself." || echo "Test completed (or timed out)"
fi

echo ""
echo "=== READY FOR DOWNLOAD ==="
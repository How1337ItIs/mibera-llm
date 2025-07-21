#!/bin/bash
# Mibera Model Conversion Script - Downloads and converts for RTX 3080

set -e  # Exit on any error

echo "🚀 Converting Mibera models for RTX 3080..."
echo "📋 This will download ~26GB and create Q4_K_M (~8.5GB) and Q3_K_M (~6.9GB) versions"
echo "💽 Requires ~50GB free disk space during conversion"
echo ""

# Check disk space (need at least 50GB)
AVAILABLE=$(df . | tail -1 | awk '{print $4}')
NEEDED=$((50 * 1024 * 1024))  # 50GB in KB

if [ $AVAILABLE -lt $NEEDED ]; then
    echo "❌ Insufficient disk space. Need 50GB, have $(($AVAILABLE / 1024 / 1024))GB"
    exit 1
fi

echo "✅ Sufficient disk space available"

# Install Python dependencies if not present
echo "📦 Installing Python dependencies..."
pip3 install --user huggingface_hub torch transformers accelerate gguf

# Create models directory
mkdir -p models
cd models

# Download original Mibera model from HuggingFace
echo "⬇️  Downloading Mibera model from HuggingFace (~26GB)..."
echo "This may take 10-30 minutes depending on your internet speed..."

if [ ! -d "mibera-hf" ]; then
    python3 -c "
from huggingface_hub import snapshot_download
print('Starting download...')
snapshot_download(
    repo_id='ivxxdegen/mibera-v1-merged',
    local_dir='mibera-hf',
    resume_download=True
)
print('Download complete!')
"
else
    echo "✅ Mibera model already downloaded"
fi

# Convert to F16 GGUF
echo "🔄 Converting to F16 GGUF format..."
if [ ! -f "mibera-f16.gguf" ]; then
    python3 ../llama.cpp/convert_hf_to_gguf.py \
        mibera-hf \
        --outfile mibera-f16.gguf \
        --outtype f16
    echo "✅ F16 conversion complete"
else
    echo "✅ F16 model already exists"
fi

# Quantize to Q4_K_M (recommended for RTX 3080)
echo "⚡ Quantizing to Q4_K_M (recommended for RTX 3080)..."
if [ ! -f "mibera-Q4_K_M.gguf" ]; then
    ../llama.cpp/build/bin/llama-quantize \
        mibera-f16.gguf \
        mibera-Q4_K_M.gguf \
        Q4_K_M
    echo "✅ Q4_K_M quantization complete"
else
    echo "✅ Q4_K_M model already exists"
fi

# Quantize to Q3_K_M (faster alternative)
echo "⚡ Quantizing to Q3_K_M (faster alternative)..."
if [ ! -f "mibera-Q3_K_M.gguf" ]; then
    ../llama.cpp/build/bin/llama-quantize \
        mibera-f16.gguf \
        mibera-Q3_K_M.gguf \
        Q3_K_M
    echo "✅ Q3_K_M quantization complete"
else
    echo "✅ Q3_K_M model already exists"
fi

# Clean up intermediate files to save space
echo "🧹 Cleaning up temporary files..."
rm -rf mibera-hf  # Remove original downloaded model
echo "✅ Cleanup complete"

# Display final results
echo ""
echo "🎉 Conversion complete! Available models:"
ls -lh *.gguf | awk '{print "  " $9 " (" $5 ")"}'

echo ""
echo "📊 Model recommendations for RTX 3080:"
echo "  • mibera-Q4_K_M.gguf - Best balance (recommended)"
echo "  • mibera-Q3_K_M.gguf - Faster, good quality"
echo "  • mibera-f16.gguf - Best quality (needs 32GB+ RAM)"
echo ""
echo "🚀 Ready to run:"
echo "  ./llama-cli -m models/mibera-Q4_K_M.gguf -p 'Hello!' -ngl 40"

cd ..  # Return to project root
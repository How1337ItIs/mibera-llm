#!/bin/bash
# cloud_setup.sh - Setup script for vast.ai cloud conversion
# Run this first on your cloud instance

set -e
echo "=== MIBERA CLOUD CONVERSION SETUP ==="

# Update system
echo "[1/6] Updating system..."
apt-get update -y
apt-get install -y wget curl git build-essential cmake python3 python3-pip

# Install Python dependencies
echo "[2/6] Installing Python dependencies..."
pip3 install --upgrade pip
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
pip3 install transformers huggingface-hub safetensors accelerate sentencepiece protobuf numpy

# Clone and build latest llama.cpp with Phi support
echo "[3/6] Building latest llama.cpp..."
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
mkdir build && cd build
cmake .. -DLLAMA_BUILD_TESTS=OFF
make -j$(nproc)
cd ../..

# Create working directory structure
echo "[4/6] Setting up directories..."
mkdir -p /workspace/mibera/{models,output,logs}
cd /workspace/mibera

# Copy llama.cpp tools
cp llama.cpp/build/bin/* /workspace/mibera/ 2>/dev/null || true
cp llama.cpp/convert_hf_to_gguf.py /workspace/mibera/ 2>/dev/null || true

echo "[5/6] Environment ready!"
echo "Working directory: /workspace/mibera"
echo "Available tools:"
ls -la /workspace/mibera/ | grep -E "(convert|quantize|main)"

echo "[6/6] Ready for model upload!"
echo ""
echo "NEXT STEPS:"
echo "1. Upload your model files to /workspace/mibera/models/"
echo "2. Run: bash convert_mibera.sh"
echo ""
echo "=== SETUP COMPLETE ==="
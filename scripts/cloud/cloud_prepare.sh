#!/bin/bash
# cloud_prepare.sh - Mibera Q3_K_M Conversion Setup
set -e

echo "=== MIBERA Q3_K_M CONVERSION SETUP ==="
echo "Target: Single Q3_K_M GGUF with enhanced evaluation"
echo "Expected time: ~50 minutes | Cost: ~$3-4"
echo ""

# System update
echo "[1/5] System update..."
apt update && apt upgrade -y
apt install -y wget curl git build-essential cmake python3 python3-pip htop nvtop

# Python environment
echo "[2/5] Python environment..."
pip3 install --upgrade pip
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
pip3 install transformers huggingface-hub safetensors accelerate sentencepiece protobuf numpy

# Latest llama.cpp with phi-4 support
echo "[3/5] Building llama.cpp..."
cd /workspace
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
mkdir build && cd build
cmake .. -DLLAMA_CUDA=ON -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
cd /workspace

# Workspace setup
echo "[4/5] Workspace structure..."
mkdir -p /workspace/mibera/{models,output,logs,eval}
cp llama.cpp/build/bin/* /workspace/mibera/ 2>/dev/null || true
cp llama.cpp/convert_hf_to_gguf.py /workspace/mibera/ 2>/dev/null || true

# Verify tools
echo "[5/5] Tool verification..."
cd /workspace/mibera
./llama-cli --help | head -3
python3 convert_hf_to_gguf.py --help | head -3

echo ""
echo "=== SETUP COMPLETE ==="
echo "Next: bash make_mibera_q3.sh"
echo "Working directory: /workspace/mibera"
df -h /workspace
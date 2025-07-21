#!/bin/bash
# Mibera RTX 3080 Setup Script - One-click CUDA + build

set -e  # Exit on any error

echo "🚀 Setting up Mibera for RTX 3080..."

# Check if NVIDIA GPU exists
if ! nvidia-smi &> /dev/null; then
    echo "❌ NVIDIA GPU not detected. Please install NVIDIA drivers first."
    exit 1
fi

echo "✅ NVIDIA GPU detected"

# Install CUDA 12.1 if not present
if ! nvcc --version | grep -q "release 12.1" &> /dev/null; then
    echo "📦 Installing CUDA 12.1..."
    
    # Download and install CUDA keyring
    wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb
    sudo dpkg -i cuda-keyring_1.0-1_all.deb
    
    # Update package list and install CUDA
    sudo apt-get update
    sudo apt-get install -y cuda-toolkit-12-1
    
    # Set environment variables
    echo 'export PATH=/usr/local/cuda-12.1/bin:$PATH' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.1/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
    
    # Apply for current session
    export PATH=/usr/local/cuda-12.1/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda-12.1/lib64:$LD_LIBRARY_PATH
    
    echo "✅ CUDA 12.1 installed"
else
    echo "✅ CUDA already installed"
fi

# Install build dependencies
echo "📦 Installing build dependencies..."
sudo apt-get update
sudo apt-get install -y build-essential cmake git python3 python3-pip

# Install Python dependencies for conversion
pip3 install torch transformers accelerate

# Build llama.cpp with CUDA support
echo "🔨 Building llama.cpp with CUDA support..."
cd llama.cpp

# Clean previous builds
rm -rf build
mkdir build && cd build

# Configure with CUDA for RTX 3080 (compute capability 8.6)
cmake .. -DLLAMA_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86 -DCMAKE_BUILD_TYPE=Release

# Build with all CPU cores
make -j$(nproc)

echo "✅ Build complete!"

# Create convenient symlinks in project root
cd ../..
ln -sf llama.cpp/build/bin/llama-cli llama-cli
ln -sf llama.cpp/build/bin/llama-quantize llama-quantize

echo ""
echo "🎉 Setup complete! Your RTX 3080 is ready for Mibera."
echo ""
echo "Next steps:"
echo "1. Download models: git lfs pull"
echo "2. Run Mibera: ./llama-cli -m models/mibera-Q4_K_M.gguf -p 'Hello!' -ngl 40"
echo ""
echo "For troubleshooting, see: runtime/docs/Ubuntu-3080-setup.md"
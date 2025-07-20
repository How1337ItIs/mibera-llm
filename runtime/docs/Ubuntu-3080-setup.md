# Mibera Setup for RTX 3080 (Ubuntu 22.04)

## 🎯 Goal: Get Mibera running with RTX 3080 acceleration

Your RTX 3080 has 10GB VRAM, so you can run **high-quality** models with fast GPU inference.

---

## 🚀 Quick Start (Recommended)

### Step 1: Download Pre-built Models
```bash
cd mibera-llm
git lfs pull  # Downloads pre-quantized models optimized for RTX 3080
```

**Available models** (in order of quality):
- `models/mibera-f16.gguf` - **Best quality** (26GB) - Uses both VRAM + RAM
- `models/mibera-Q4_K_M.gguf` - **Excellent** (8.5GB) - Fits entirely in VRAM + RAM  
- `models/mibera-Q3_K_M.gguf` - **Good** (6.9GB) - Fast, good quality

### Step 2: Install CUDA + Build
```bash
./scripts/setup-3080.sh  # Installs CUDA, builds llama.cpp with GPU support
```

### Step 3: Run Mibera
```bash
# For best quality (if you have 32GB+ RAM):
./llama-cli -m models/mibera-f16.gguf -p "Hello! Introduce yourself as Mibera." -ngl 40

# For excellent quality (recommended):
./llama-cli -m models/mibera-Q4_K_M.gguf -p "Hello! Introduce yourself as Mibera." -ngl 40

# -ngl 40 = offload all 40 layers to GPU for maximum speed
```

---

## ⚙️ Manual Setup (If Quick Start Fails)

### Install CUDA 12.1
```bash
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb
sudo dpkg -i cuda-keyring_1.0-1_all.deb
sudo apt-get update
sudo apt-get -y install cuda-toolkit-12-1
export PATH=/usr/local/cuda-12.1/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.1/lib64:$LD_LIBRARY_PATH
```

### Build llama.cpp with CUDA
```bash
cd runtime/llama.cpp-patched
mkdir build && cd build
cmake .. -DLLAMA_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86  # RTX 3080 = compute 8.6
make -j$(nproc)
```

### Convert Model (If No Pre-built Available)
```bash
# Download original Mibera model
huggingface-cli download ivxxdegen/mibera-v1-merged --local-dir ./mibera-hf

# Convert to GGUF
python3 runtime/llama.cpp-patched/convert_hf_to_gguf.py ./mibera-hf --outfile mibera-f16.gguf --outtype f16

# Quantize for better performance
./build/bin/llama-quantize mibera-f16.gguf mibera-Q4_K_M.gguf Q4_K_M
```

---

## 🎮 Usage Examples

### Chat Mode
```bash
./llama-cli -m models/mibera-Q4_K_M.gguf -p "Hello!" -i -ngl 40 --color
```

### High Performance Settings
```bash
# Max speed (uses all GPU):
./llama-cli -m models/mibera-Q4_K_M.gguf -ngl 40 -c 4096 -b 512

# Best quality with larger context:
./llama-cli -m models/mibera-f16.gguf -ngl 40 -c 8192 -b 256
```

---

## 🔧 Troubleshooting

### GPU Not Detected
```bash
nvidia-smi  # Should show RTX 3080
nvcc --version  # Should show CUDA 12.1+
```

### Out of Memory
- Try Q3_K_M model instead of Q4_K_M
- Reduce context size: `-c 2048`
- Reduce batch size: `-b 256`

### Slow Performance  
- Verify GPU offloading: `-ngl 40` (should see "using CUDA" in output)
- Check GPU utilization: `nvidia-smi` while running

---

## 📊 Expected Performance (RTX 3080)

| Model | Size | Quality | Speed | VRAM Usage |
|-------|------|---------|-------|------------|
| F16 | 26GB | ⭐⭐⭐⭐⭐ | 25+ tok/s | ~10GB |
| Q4_K_M | 8.5GB | ⭐⭐⭐⭐ | 35+ tok/s | ~9GB |
| Q3_K_M | 6.9GB | ⭐⭐⭐ | 45+ tok/s | ~8GB |

**Recommendation**: Start with Q4_K_M - excellent quality and fits comfortably in your 10GB VRAM.
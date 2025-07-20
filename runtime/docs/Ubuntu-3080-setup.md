# Mibera Setup for RTX 3080 (Ubuntu 22.04)

## 🎯 Goal: Get Mibera running with RTX 3080 acceleration

Your RTX 3080 has 10GB VRAM, so you can run **high-quality** models with fast GPU inference.

**Requirements:** 50GB free disk space for model conversion

---

## 🚀 Quick Start (3 commands)

```bash
git clone --depth 1 --branch runtime https://github.com/How1337ItIs/mibera-llm.git
cd mibera-llm
./runtime/scripts/setup-3080.sh      # Installs CUDA + builds llama.cpp
./runtime/scripts/convert-models.sh  # Downloads + converts Mibera models (~30 min)
```

Then run:
```bash
./llama-cli -m models/mibera-Q4_K_M.gguf -p "Hello! Introduce yourself as Mibera." -ngl 40
```

**That's it!** The scripts handle everything automatically.

---

## 🔧 What the Scripts Do

### setup-3080.sh
- Detects your RTX 3080
- Installs CUDA 12.1 toolkit
- Builds llama.cpp with GPU support (compute 8.6)
- Creates convenient symlinks

### convert-models.sh  
- Downloads Mibera model from HuggingFace (~26GB)
- Converts to F16 GGUF format
- Creates Q4_K_M (8.5GB) - **recommended**
- Creates Q3_K_M (6.9GB) - faster alternative
- Cleans up temporary files

---

## 🎮 Usage Examples

### Basic Chat
```bash
./llama-cli -m models/mibera-Q4_K_M.gguf -p "Hello!" -i -ngl 40 --color
```

### High Performance Settings
```bash
# Max speed (all layers on GPU):
./llama-cli -m models/mibera-Q4_K_M.gguf -ngl 40 -c 4096 -b 512

# Best quality with larger context:
./llama-cli -m models/mibera-f16.gguf -ngl 40 -c 8192 -b 256
```

### Key Parameters
- `-ngl 40` = Offload all 40 layers to GPU (maximum speed)
- `-c 4096` = Context window size (larger = more memory)
- `-b 512` = Batch size (larger = faster, more VRAM)
- `-i` = Interactive chat mode

---

## 🔧 Troubleshooting

### GPU Not Detected
```bash
nvidia-smi  # Should show RTX 3080
nvcc --version  # Should show CUDA 12.1+
```
**Fix:** Install NVIDIA drivers first, then re-run setup script

### Out of VRAM
Try smaller model or reduce settings:
```bash
# Use Q3_K_M instead of Q4_K_M:
./llama-cli -m models/mibera-Q3_K_M.gguf -ngl 40

# Or reduce context/batch:
./llama-cli -m models/mibera-Q4_K_M.gguf -ngl 35 -c 2048 -b 256
```

### Slow Performance  
```bash
# Verify GPU usage while running:
nvidia-smi

# Check that you see "using CUDA" in llama.cpp output
# Should show high GPU utilization (80%+)
```

### Build Errors
```bash
# Clean rebuild:
cd runtime/llama.cpp-patched
rm -rf build
mkdir build && cd build
cmake .. -DLLAMA_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86
make -j$(nproc)
```

### Conversion Errors
```bash
# Check disk space:
df -h .

# Check Python dependencies:
pip3 install --user huggingface_hub torch transformers accelerate gguf

# Manual conversion:
cd models
python3 -c "from huggingface_hub import snapshot_download; snapshot_download('ivxxdegen/mibera-v1-merged', 'mibera-hf')"
```

---

## 📊 Expected Performance (RTX 3080)

| Model | Size | Quality | Speed | VRAM Usage | Best For |
|-------|------|---------|-------|------------|----------|
| Q4_K_M | 8.5GB | ⭐⭐⭐⭐ | 35+ tok/s | ~9GB | **Recommended** |
| Q3_K_M | 6.9GB | ⭐⭐⭐ | 45+ tok/s | ~8GB | Speed focused |
| F16 | 26GB | ⭐⭐⭐⭐⭐ | 25+ tok/s | ~10GB | Quality focused |

**System Requirements:**
- RTX 3080 (10GB VRAM)
- 16GB+ system RAM (32GB for F16)
- 50GB free disk space for conversion
- Ubuntu 22.04 + NVIDIA drivers

---

## 🚨 Important Notes

### About the Patches
This version includes critical fixes for Mibera's architecture:
- **Bias tensor fix** - All LayerNorm biases made optional
- **GQA support** - Handles Mibera's Grouped Query Attention (32:8 head ratio)

Without these patches, Mibera **will not load** in standard llama.cpp.

### Performance Tuning
```bash
# Monitor while running:
watch -n 1 'nvidia-smi; echo; ps aux | grep llama-cli'

# For maximum quality, use F16 (if you have 32GB+ RAM):
./llama-cli -m models/mibera-f16.gguf -ngl 40 -c 8192

# For maximum speed, use Q3_K_M:
./llama-cli -m models/mibera-Q3_K_M.gguf -ngl 40 -c 4096 -b 512
```

---

## 💡 Pro Tips

1. **Start with Q4_K_M** - Best balance for RTX 3080
2. **Use `-ngl 40`** - Offloads all layers to GPU for max speed  
3. **Monitor VRAM** - `nvidia-smi` should show 8-9GB usage
4. **Increase context** - `-c 8192` for longer conversations
5. **Save disk space** - Delete F16 after quantizing if space is tight

Claude Code can help debug any issues! 🤖
# Mibera LLM - RTX 3080 Ready

**90-second setup for high-quality Mibera inference on Ubuntu + RTX 3080**

## 🚀 Quick Start

```bash
git clone --depth 1 --branch runtime https://github.com/How1337ItIs/mibera-llm.git
cd mibera-llm
./runtime/scripts/setup-3080.sh      # Install CUDA + build patched llama.cpp
./runtime/scripts/convert-models.sh  # Download + convert models (~30 min)
./llama-cli -m models/mibera-Q4_K_M.gguf -p "Hello!" -ngl 40
```

**Requirements:** RTX 3080, Ubuntu 22.04, 50GB free space

## 📁 Repository Structure

```
├── docs/
│   ├── design/          # Architecture research, GQA analysis, patch details
│   └── logs/            # Conversion logs and debugging history  
├── scripts/
│   ├── convert/         # Model conversion and quantization
│   ├── inference/       # Benchmarking and runtime helpers
│   └── cloud/           # Cloud setup (vast.ai, etc.)
├── models/              # Your .gguf files live here (git-ignored)
├── runtime/             # Clean runtime distribution
└── llama.cpp/           # Patched llama.cpp with bias + GQA fixes
```

## ⚡ What Makes This Special

This isn't vanilla llama.cpp - it includes **critical patches** for Mibera:

- **Bias tensor fix** - All PHI2 LayerNorm biases made optional
- **GQA support** - Handles Mibera's Grouped Query Attention (32:8 head ratio)

Without these patches, Mibera **will not load** in standard llama.cpp.

## 🎯 Performance Targets (RTX 3080)

| Model | Size | Quality | Speed | VRAM | Best For |
|-------|------|---------|-------|------|----------|
| Q4_K_M | 8.5GB | ⭐⭐⭐⭐ | 35+ tok/s | 9GB | **Recommended** |
| Q3_K_M | 6.9GB | ⭐⭐⭐ | 45+ tok/s | 8GB | Speed focused |
| Q2_K | 5.2GB | ⭐⭐ | 55+ tok/s | 7GB | Memory constrained |

## 🔧 Manual Build (Advanced)

```bash
cd llama.cpp
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DLLAMA_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86
make -j$(nproc)
```

## 📚 Documentation

- **Quick setup**: `runtime/docs/Ubuntu-3080-setup.md`
- **Architecture deep-dive**: `docs/design/`
- **Conversion logs**: `docs/logs/`

## 🆘 Need Help?

1. Check the troubleshooting guide: `runtime/docs/Ubuntu-3080-setup.md`
2. Ask Claude Code - it knows this repo well!
3. All scripts include verbose error messages

---

**Built for developers who want Mibera running fast, not fighting with configs.**
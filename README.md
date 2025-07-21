# Mibera LLM - RTX 3080 Ready

**Brother-proof setup for high-quality Mibera inference on Ubuntu + RTX 3080**

## 🚀 Two-Command Setup

```bash
git clone --depth 1 --branch runtime https://github.com/How1337ItIs/mibera-llm.git
cd mibera-llm
./scripts/setup/setup-3080.sh        # Install CUDA + build (~10 min)
./scripts/setup/convert-models.sh    # Download + convert (~30 min)
./llama-cli -m models/mibera-Q4_K_M.gguf -p "Hello!" -ngl 40
```

**Requirements:** RTX 3080, Ubuntu 22.04, 50GB free space

---

## 📁 Clean Repository Structure

```
├── docs/                    # All documentation and logs
│   ├── design/             # Architecture research, GQA analysis
│   ├── logs/               # Conversion history and debugging
│   └── Ubuntu-3080-setup.md # Detailed setup guide
├── scripts/
│   ├── setup/              # setup-3080.sh, convert-models.sh
│   ├── convert/            # Model conversion utilities
│   ├── inference/          # Benchmarking and runtime helpers
│   └── cloud/              # Cloud setup scripts
├── models/                 # Your .gguf files (git-ignored)
└── llama.cpp/              # Patched llama.cpp with Mibera fixes
```

---

## ⚡ What Makes This Special

This includes **critical patches** for Mibera that aren't in vanilla llama.cpp:

- **✅ Bias tensor fix** - All PHI2 LayerNorm biases made optional
- **✅ GQA support** - Handles Mibera's Grouped Query Attention (32:8 head ratio)

Without these patches, Mibera **will not load** in standard llama.cpp.

---

## 🎯 Performance Targets (RTX 3080)

| Model | Size | Quality | Speed | VRAM | Best For |
|-------|------|---------|-------|------|----------|
| **Q4_K_M** | **8.5GB** | **⭐⭐⭐⭐** | **35+ tok/s** | **9GB** | **Recommended** |
| Q3_K_M | 6.9GB | ⭐⭐⭐ | 45+ tok/s | 8GB | Speed focused |
| Q2_K | 5.2GB | ⭐⭐ | 55+ tok/s | 7GB | Memory constrained |

**Perfect balance:** Q4_K_M gives excellent quality with full GPU acceleration.

---

## 🔧 Manual Build (Advanced)

```bash
cd llama.cpp
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DLLAMA_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=86
make -j$(nproc)
```

---

## 📚 Documentation

- **Quick setup**: `docs/Ubuntu-3080-setup.md`
- **Architecture deep-dive**: `docs/design/`
- **Conversion history**: `docs/logs/`

---

## 🆘 Need Help?

1. **Check troubleshooting**: `docs/Ubuntu-3080-setup.md`
2. **Ask Claude Code** - it knows this repo inside and out
3. **All scripts include verbose error messages**

---

**Built for developers who want Mibera running fast, not fighting with configs.**

*Your brother gets the full 35+ tokens/second experience with zero fuss.*
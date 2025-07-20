# Mibera Runtime - RTX 3080 Optimized

**High-quality Mibera model runner optimized for RTX 3080 GPUs.**

This branch contains everything needed to run Mibera with GPU acceleration - no research files or development artifacts.

## 🚀 Quick Start (Local Conversion)

```bash
git clone --depth 1 --branch runtime https://github.com/How1337ItIs/mibera-llm.git
cd mibera-llm
./runtime/scripts/setup-3080.sh  # Installs CUDA + builds everything
./runtime/scripts/convert-models.sh  # Downloads + converts Mibera models
```

Then run:
```bash
./llama-cli -m models/mibera-Q4_K_M.gguf -p "Hello! Introduce yourself as Mibera." -ngl 40
```

**Requirements:** ~50GB free disk space for conversion process

## 📋 What's Included

- **Patched llama.cpp** - Fixed for Mibera's PHI4-style architecture (bias + GQA support)
- **RTX 3080 setup script** - One-click CUDA installation + build
- **Model conversion script** - Downloads from HuggingFace + quantizes locally
- **Detailed docs** - See `docs/Ubuntu-3080-setup.md`

## 🎯 Recommended Settings

**RTX 3080 (10GB VRAM):**
- Use `mibera-Q4_K_M.gguf` for best balance of quality/speed
- `-ngl 40` to offload all layers to GPU  
- Expect 35+ tokens/second

## 🔧 Need Help?

Full setup guide: [docs/Ubuntu-3080-setup.md](docs/Ubuntu-3080-setup.md)

Claude Code can help with any build or conversion issues!
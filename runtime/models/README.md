# Models Directory

This directory will contain your Mibera models after running the conversion script.

## 🚀 Quick Setup

Run the conversion script to download and create optimized models:
```bash
./runtime/scripts/convert-models.sh
```

This will create:
- `mibera-Q4_K_M.gguf` (8.5GB) - **Recommended for RTX 3080**
- `mibera-Q3_K_M.gguf` (6.9GB) - Faster alternative  
- `mibera-f16.gguf` (26GB) - Best quality (requires 32GB+ RAM)

## 📋 Requirements

- **50GB free disk space** during conversion
- **Fast internet** for ~26GB download from HuggingFace
- **30+ minutes** conversion time

## 🎯 Usage

After conversion, run Mibera with:
```bash
./llama-cli -m models/mibera-Q4_K_M.gguf -p "Hello!" -ngl 40
```

The conversion script handles everything automatically - just run it and wait!
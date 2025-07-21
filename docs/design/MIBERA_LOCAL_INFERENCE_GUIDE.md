# Mibera Model Local Inference Guide

## Overview

This guide covers running the converted Mibera model (Phi-4 variant, 12.5B parameters) locally on your system. The model has been successfully converted from HuggingFace format to GGUF with aggressive quantizations optimized for 12GB RAM systems.

## Model Information

### Source Model
- **Original**: ivxxdegen/mibera-v1-merged
- **Architecture**: Phi-4 variant (12.5B parameters)
- **Context Length**: 4096 tokens
- **Vocabulary Size**: 50257 tokens

### Available Quantizations

| Model File | Size | RAM Usage | Quality | Recommended For |
|------------|------|-----------|---------|-----------------|
| `mibera-Q4_K_M-final.gguf` | 8.5GB | ~10-11GB | High | 16GB+ RAM systems |
| `mibera-Q3_K_M-final.gguf` | 6.9GB | ~8-9GB | Good | **12GB RAM (Recommended)** |
| `mibera-Q2_K-final.gguf` | 5.2GB | ~6-7GB | Acceptable | 8GB RAM or heavy multitasking |

### Model Verification (SHA256)
```
9f49e37a3e58fe77365fe39bcd3f9c3abf28b86721fed1e35b49a79d711769e6  mibera-Q4_K_M-final.gguf
a88f30a974c55bbd54d7c6104f893ecdde5b542f405eebfd9d1bdfc61e648811  mibera-Q3_K_M-final.gguf
19b3dd290ac0b7eb2690e8d5801365b57b54878c28d95a70bc3f107f6e05895a  mibera-Q2_K-final.gguf
```

## Installation Requirements

### System Requirements
- **Minimum RAM**: 8GB (for Q2_K)
- **Recommended RAM**: 12GB+ (for Q3_K_M)
- **Storage**: 10GB free space
- **OS**: Windows 10/11, macOS, or Linux

### Software Prerequisites
1. **Python 3.8+** (for some tools)
2. **Git** (for downloading tools)
3. **C++ Build Tools** (if compiling from source)

## Installation Methods

### Method 1: Ollama (Recommended for Beginners)

#### Install Ollama
```bash
# Windows (PowerShell as Administrator)
winget install Ollama.Ollama

# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.ai/install.sh | sh
```

#### Run the Model
```bash
# Start Ollama service (if not auto-started)
ollama serve

# In another terminal, run the model
ollama run "C:/Users/natha/mibera_llm_final/mibera-Q3_K_M-final.gguf"

# Or use absolute path on your system
ollama run "/path/to/your/mibera-Q3_K_M-final.gguf"
```

#### Interactive Chat
```bash
# Basic chat
ollama run mibera-q3 "Hello, tell me about yourself"

# With custom parameters
ollama run mibera-q3 --context 512 "What can you help me with?"
```

### Method 2: llama.cpp (Advanced Users)

#### Install llama.cpp
```bash
# Clone repository
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# Windows (with Visual Studio)
mkdir build
cd build
cmake .. -DLLAMA_CUBLAS=ON  # If you have NVIDIA GPU
cmake --build . --config Release

# macOS/Linux
make -j4
```

#### Run Inference
```bash
# Basic inference
./main -m /path/to/mibera-Q3_K_M-final.gguf -p "Hello, I am" -n 50

# Interactive mode
./main -m /path/to/mibera-Q3_K_M-final.gguf -i

# With custom context size for 12GB RAM
./main -m /path/to/mibera-Q3_K_M-final.gguf -c 512 -i
```

### Method 3: Text Generation WebUI

#### Install oobabooga/text-generation-webui
```bash
# Clone and setup
git clone https://github.com/oobabooga/text-generation-webui.git
cd text-generation-webui

# Windows
start_windows.bat

# Linux/macOS
./start_linux.sh
```

#### Load Model
1. Open web interface at `http://localhost:7860`
2. Go to "Model" tab
3. Browse and select your GGUF file
4. Click "Load"

## Performance Optimization

### Memory Management

#### For 12GB RAM Systems (Recommended Settings)
```bash
# Ollama
ollama run model --context 512 --num-predict 100

# llama.cpp
./main -m model.gguf -c 512 -n 100 --mlock
```

#### For 8GB RAM Systems
```bash
# Use Q2_K model with reduced context
ollama run mibera-q2k --context 256 --num-predict 50

# llama.cpp with memory optimization
./main -m mibera-Q2_K-final.gguf -c 256 -n 50 --no-mmap
```

### GPU Acceleration (Optional)

#### NVIDIA GPU (CUDA)
```bash
# Ollama automatically detects GPU
ollama run model

# llama.cpp with CUDA
./main -m model.gguf -ngl 32  # Offload 32 layers to GPU
```

#### Apple Silicon (Metal)
```bash
# Automatic in most tools
ollama run model

# llama.cpp
./main -m model.gguf -ngl 32
```

## Usage Examples

### Basic Chat Session
```bash
ollama run mibera-q3 "What are the key principles of software engineering?"
```

### Code Generation
```bash
ollama run mibera-q3 "Write a Python function to calculate the Fibonacci sequence"
```

### Analysis Tasks
```bash
ollama run mibera-q3 "Analyze the pros and cons of microservices architecture"
```

### Creative Writing
```bash
ollama run mibera-q3 "Write a short story about artificial intelligence in the year 2030"
```

## Troubleshooting

### Common Issues

#### Out of Memory Errors
**Symptoms**: Model fails to load or crashes during inference
**Solutions**:
1. Use smaller quantization (Q3_K_M → Q2_K)
2. Reduce context size (`--context 256`)
3. Close other applications
4. Restart system to free RAM

#### Slow Inference
**Symptoms**: Very slow response generation
**Solutions**:
1. Enable GPU acceleration if available
2. Use mlock/mmap optimizations
3. Increase context size gradually
4. Check for background processes

#### Model Loading Errors
**Symptoms**: "Cannot load model" or corruption errors
**Solutions**:
1. Verify SHA256 hash matches expected values
2. Re-download model if corrupted
3. Check file permissions
4. Ensure sufficient disk space

### Performance Tuning

#### Context Size Guidelines
| RAM Available | Recommended Context | Max Context |
|---------------|-------------------|-------------|
| 8GB | 256 | 512 |
| 12GB | 512 | 1024 |
| 16GB+ | 1024 | 2048+ |

#### Batch Size Optimization
```bash
# Small batch for memory-constrained systems
./main -m model.gguf -b 1 -c 512

# Larger batch for better performance
./main -m model.gguf -b 8 -c 1024
```

## API Integration

### Ollama REST API
```bash
# Start Ollama server
ollama serve

# Make API calls
curl http://localhost:11434/api/generate \
  -d '{
    "model": "mibera-q3",
    "prompt": "Hello world",
    "stream": false
  }'
```

### Python Integration
```python
import requests

def query_mibera(prompt, model="mibera-q3"):
    response = requests.post(
        "http://localhost:11434/api/generate",
        json={
            "model": model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "num_predict": 100,
                "temperature": 0.7
            }
        }
    )
    return response.json()["response"]

# Usage
result = query_mibera("Explain quantum computing")
print(result)
```

## Best Practices

### Memory Management
1. **Monitor RAM usage** during inference
2. **Start with conservative settings** (small context, Q2_K model)
3. **Gradually increase parameters** as system allows
4. **Close unnecessary applications** before running inference

### Quality vs Performance
1. **Q4_K_M**: Best quality, requires 16GB+ RAM
2. **Q3_K_M**: Good balance, works well on 12GB RAM
3. **Q2_K**: Fastest inference, acceptable quality for most tasks

### Security Considerations
1. **Validate model hashes** before use
2. **Run in isolated environment** if processing sensitive data
3. **Monitor resource usage** to prevent system overload
4. **Keep tools updated** for security patches

## Model Metadata

### Technical Specifications
```
Architecture: Phi-4 variant
Parameters: 12.5B
Hidden Size: 5120
Attention Heads: 32
Layers: 40
Vocabulary: 50257 tokens
Context Length: 4096 tokens
FFN Architecture: Split gate/up (17920 each)
```

### Training Information
- **Base Model**: Microsoft Phi-4 architecture
- **Variant**: ivxxdegen/mibera-v1-merged
- **Conversion**: Custom GGUF conversion with FFN splitting
- **Quantization**: llama.cpp quantization methods

## Support and Updates

### Getting Help
1. **Check logs** for error messages
2. **Verify system requirements** match your setup
3. **Test with smaller models** first
4. **Monitor resource usage** during inference

### Model Updates
- **Current Version**: mibera-*-final.gguf (July 2025)
- **SHA256 verification** recommended for integrity
- **Backup models** available in multiple quantizations

---

## Quick Start Checklist

- [ ] Install Ollama or llama.cpp
- [ ] Download appropriate model size for your RAM
- [ ] Verify SHA256 hash
- [ ] Test with small context size first
- [ ] Gradually increase parameters
- [ ] Monitor system performance
- [ ] Enjoy local AI inference!

For advanced configuration and troubleshooting, refer to the respective tool documentation:
- [Ollama Documentation](https://ollama.ai/docs)
- [llama.cpp Documentation](https://github.com/ggerganov/llama.cpp)
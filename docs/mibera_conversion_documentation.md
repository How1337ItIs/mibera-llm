# MIBERA MODEL CONVERSION DOCUMENTATION

## CURRENT STATUS
- **✅ DOWNLOAD COMPLETE**: Genuine `ivxxdegen/mibera-v1-merged` model fully downloaded
- **❌ CONVERSION BLOCKED**: GGUF conversion failing due to architecture compatibility issues
- **⚠️ DISK SPACE**: 38.3GB free, 60GB model downloaded, need conversion to proceed

## COMPLETE FILE INVENTORY

### Downloaded Model Files (All Present)
```
C:\mibera\models\mibera\
├── model-00001-of-00013.safetensors ✅
├── model-00002-of-00013.safetensors ✅
├── model-00003-of-00013.safetensors ✅
├── model-00004-of-00013.safetensors ✅
├── model-00005-of-00013.safetensors ✅
├── model-00006-of-00013.safetensors ✅
├── model-00007-of-00013.safetensors ✅
├── model-00008-of-00013.safetensors ✅
├── model-00009-of-00013.safetensors ✅
├── model-00010-of-00013.safetensors ✅
├── model-00011-of-00013.safetensors ✅
├── model-00012-of-00013.safetensors ✅
├── model-00013-of-00013.safetensors ✅
├── config.json
├── generation_config.json
├── model.safetensors.index.json
├── tokenizer.json
├── tokenizer_config.json
├── vocab.json
├── merges.txt
├── special_tokens_map.json
├── requirements.txt
└── README.md
```

### Available Tools
```
C:\mibera\tools\
├── llama-cli.exe (build 3613)
├── llama-quantize.exe (build 3613)
├── llama-server.exe (build 3613)
├── convert.py (outdated - DREAM model error)
├── convert_new.py (b3613 version - doesn't support architecture)
└── [50+ other llama.cpp tools]
```

## MODEL ARCHITECTURE ANALYSIS

### Config.json Contents
```json
{
  "_name_or_path": "microsoft/phi-4",
  "architectures": ["AutoModelForCausalLM"],
  "model_type": "causal_lm", 
  "num_hidden_layers": 32,
  "num_attention_heads": 16,
  "num_key_value_heads": 8,
  "hidden_size": 4096,
  "vocab_size": 50257,
  "torch_dtype": "bfloat16",
  "tie_word_embeddings": false
}
```

**Key Issue**: Model reports as `AutoModelForCausalLM` but is actually a Phi-4 fine-tune. Conversion tools don't recognize this specific architecture variant.

## ATTEMPTED SOLUTIONS & ERRORS

### 1. Original Conversion Script (convert.py)
```bash
python tools/convert.py models/mibera --outfile models/mibera-f16.gguf --outtype f16
```
**Error**: 
```
AttributeError: DREAM
class DreamModel(TextModel):
    model_arch = gguf.MODEL_ARCH.DREAM
```
**Cause**: Script from older llama.cpp version, incompatible enum values

### 2. Updated Conversion Script (convert_new.py)
```bash
python tools/convert_new.py models/mibera --outfile models/mibera-f16.gguf --outtype f16
```
**Error**:
```
ERROR:hf-to-gguf:Model AutoModelForCausalLM is not supported
```
**Cause**: Generic architecture name not mapped to specific converter

### 3. Direct Quantization Attempt
```bash
./tools/llama-quantize.exe models/mibera models/mibera-Q3_K_M.gguf Q3_K_M
```
**Error**:
```
gguf_init_from_file: failed to open 'models/mibera': 'Permission denied'
```
**Cause**: Quantize tool expects GGUF input, not safetensors directory

### 4. Phi-4 Specific Conversion
```bash
python tools/convert_new.py models/mibera --outfile models/mibera-f16.gguf --model-name phi-4
```
**Error**: Same `AutoModelForCausalLM not supported` error

## SYSTEM CONSTRAINTS

### Hardware Limitations
- **CPU**: Intel i3-1115G4 (2C/4T, AVX2)
- **RAM**: 12GB total (~11.8GB usable)
- **GPU**: Intel UHD integrated only (no CUDA)
- **Disk**: 38.3GB free space remaining

### Space Requirements
- **Current usage**: ~60GB (model files)
- **Conversion process**: Would need ~30GB more for F16 GGUF
- **Final quantized**: ~5-6GB (Q3_K_M target)
- **Problem**: Not enough space for traditional 2-step conversion

### Target Output
- Primary: `mibera-Q3_K_M.gguf` (~5GB, optimal for 12GB RAM)
- Secondary: `mibera-Q2_K.gguf` (~3GB, emergency low-RAM option)

## TECHNICAL ENVIRONMENT

### Python Environment
```
Python 3.10.6
Installed packages:
- huggingface-hub 0.33.4
- torch (latest)
- transformers 4.53.2
- sentencepiece
- protobuf
- numpy 2.2.6
- gguf 0.17.1
- safetensors 0.5.3
```

### llama.cpp Build
```
Version: b3613 (fc54ef0d)
Compiler: MSVC 19.29.30154.0 for x64
Features: AVX2, F16C support
Missing: CURL support (build failed earlier)
```

## CONVERSION REQUIREMENTS

### What's Needed
1. **Architecture Recognition**: Converter that recognizes Phi-4 fine-tunes disguised as `AutoModelForCausalLM`
2. **Space Efficiency**: Direct quantization or immediate cleanup to avoid 100GB+ peak usage
3. **Compatibility**: Work with existing llama.cpp quantize tools (build 3613)

### Possible Solutions to Explore
1. **Update llama.cpp**: Get newer build with Phi-4 support
2. **Manual Conversion**: Write custom converter for this specific architecture
3. **Alternative Tools**: Try different GGUF conversion tools
4. **Config Modification**: Modify model config to be recognized correctly
5. **Direct Loading**: Use transformers → manual GGUF export

## FILES CREATED FOR SOLUTION

### Space-Optimized Scripts
- `convert_space_optimized.ps1` - Immediate cleanup conversion
- `auto_convert_when_ready.ps1` - Auto-monitor and convert
- `check_status.ps1` - Progress monitoring

### Attempted Solutions
- `manual_convert.py` - Direct conversion attempt
- `convert_working.py` - Transformers-based approach
- `test_model_direct.py` - Direct model testing

### Runners (Ready When Converted)
- `run_mibera.ps1` - Main launcher with modes
- `run_mibera_direct.ps1` - Status display

## EXACT COMMANDS TO REPRODUCE

### Verify Model Integrity
```bash
cd "C:\mibera"
dir models\mibera\model-*.safetensors | find /c "safetensors"
# Should return: 13
```

### Check Space
```bash
dir C:\ | findstr "bytes free"
```

### Current Working Directory
```
C:\mibera\
├── models\mibera\ (60GB - complete model)
├── tools\ (llama.cpp binaries)
├── convert_space_optimized.ps1
├── run_mibera.ps1
└── [various conversion attempts]
```

## GOAL
Convert `C:\mibera\models\mibera\` (13 safetensor files) → `C:\mibera\models\mibera-Q3_K_M.gguf` using minimal disk space, compatible with existing llama.cpp tools.

**The model is authentic `ivxxdegen/mibera-v1-merged` and ready - just need working conversion for this Phi-4 architecture variant.**
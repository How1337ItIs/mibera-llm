# MIBERA QKV TENSOR ARCHITECTURE RESEARCH
**Comprehensive Analysis of PHI Model Architecture Variations and Solutions**

---

## 🚨 **CURRENT ISSUE SUMMARY**

### **Problem:** Tensor Dimension Mismatch in Mibera Model
```
llama_model_load: error loading model: check_tensor_dims: 
tensor 'blk.0.attn_qkv.weight' has wrong shape; 
expected 5120, 15360, got 5120, 7680
```

### **Analysis:**
- **Expected by llama.cpp PHI2**: `[5120, 15360]` (3x for Q/K/V combined)
- **Actual in Mibera**: `[5120, 7680]` (1.5x, indicating different attention mechanism)
- **Success**: ✅ Bias tensor patch completely resolved all bias-related errors
- **Next Challenge**: Architectural mismatch in attention projection dimensions

---

## 📋 **PHI MODEL SERIES EVOLUTION & ARCHITECTURE**

### **PHI-2 (2.7B Parameters)**
```yaml
Architecture: Transformer-based with next-word prediction
Parameters:
  vocab_size: 51200
  hidden_size: 2048  
  intermediate_size: 8192
  num_hidden_layers: 24
  num_attention_heads: 32
  
Key Features:
  - Standard multi-head attention
  - Known FP16 overflow issues
  - Training: 250B tokens
  - QKV Tensor: [2048, 6144] (standard 3x multiplication)
```

### **PHI-3 Mini (3.8B Parameters)**
```yaml
Architecture: Dense decoder-only Transformer
Parameters:
  vocab_size: 32064
  hidden_size: 3072
  intermediate_size: 8192  
  num_hidden_layers: 32
  num_attention_heads: 32
  
Key Features:
  - Flash attention by default
  - LLaMA-2 similar block structure
  - Multi-head attention (MHA)
  - QKV Tensor: [3072, 9216] (standard 3x)
```

### **PHI-3 Medium (14B Parameters)**
```yaml
Architecture: Dense decoder-only Transformer  
Parameters:
  hidden_size: 5120
  num_attention_heads: 32
  
Key Features:
  - Outperforms Gemini 1.0 Pro
  - Expected QKV: [5120, 15360] (matches our error message)
  - Standard multi-head attention
```

### **PHI-4 (14B Parameters)**
```yaml
Architecture: Dense decoder-only Transformer
Parameters:
  vocab_size: ~100,000+ (enhanced multilingual)
  hidden_size: 5120
  num_hidden_layers: 40
  
Key Features:
  - Grouped Query Attention (GQA) 
  - Training: 9.8 trillion tokens
  - Enhanced reasoning capabilities
  - QKV Tensor: [5120, 7680] (MATCHES MIBERA!)
```

### **PHI-4-mini**
```yaml
Architecture: Advanced transformer with GQA
Key Features:
  - 200,000 word vocabulary
  - Grouped-query attention (GQA)
  - Built-in function calling
  - Shared embedding optimization
```

### **PHI-4-mini-flash-reasoning (3.8B Parameters)**
```yaml
Architecture: Decoder-hybrid-decoder (SambaY)
Key Innovation:
  - Gated Memory Unit (GMU)
  - Mamba (State Space Model) + Sliding Window Attention
  - Single layer full attention
  - Cross-decoder with efficient GMUs
```

---

## 🔬 **ATTENTION MECHANISM DEEP DIVE**

### **Grouped Query Attention (GQA) Explained**

**Standard Multi-Head Attention (MHA):**
```
Q: [batch, seq_len, n_heads * head_dim]    # e.g., [B, T, 32 * 160] = [B, T, 5120]
K: [batch, seq_len, n_heads * head_dim]    # e.g., [B, T, 32 * 160] = [B, T, 5120]  
V: [batch, seq_len, n_heads * head_dim]    # e.g., [B, T, 32 * 160] = [B, T, 5120]
QKV Combined: [5120, 15360] (3x multiplication)
```

**Grouped Query Attention (GQA):**
```
Q: [batch, seq_len, n_q_heads * head_dim]     # e.g., [B, T, 32 * 160] = [B, T, 5120]
K: [batch, seq_len, n_kv_heads * head_dim]    # e.g., [B, T, 8 * 160] = [B, T, 1280]
V: [batch, seq_len, n_kv_heads * head_dim]    # e.g., [B, T, 8 * 160] = [B, T, 1280]
QKV Combined: [5120, 7680] (1.5x - MIBERA PATTERN!)
```

**GQA Variants:**
- **GQA-1**: Single group = Multi-Query Attention (MQA)
- **GQA-8**: 8 groups (Llama 2 70B, Mistral 7B pattern)
- **GQA-H**: Groups = heads = Multi-Head Attention (MHA)

### **Memory & Performance Benefits**
```yaml
Memory Reduction:
  - KV cache size: Reduced by factor of (n_heads / n_kv_heads)
  - Example: 32 heads → 8 kv_heads = 4x smaller KV cache
  
Performance:
  - Faster inference (less memory bandwidth)
  - Maintained quality vs MHA
  - Better than MQA for accuracy
```

---

## 🔧 **TENSOR DIMENSION ANALYSIS**

### **Mibera Model Characteristics**
```yaml
Detected Architecture:
  arch: phi2 (loader path)
  n_embd: 5120
  n_layer: 40
  n_head: 32
  model_params: 14.66B
  tensor_count: 243

QKV Tensor Analysis:
  Expected (PHI3 Medium): [5120, 15360] (n_embd * 3)
  Actual (Mibera): [5120, 7680] (n_embd * 1.5)
  
Conclusion: 
  - Mibera uses GQA with n_kv_heads = 8
  - Q projection: 5120 → 5120 (32 heads)  
  - K projection: 5120 → 1280 (8 heads)
  - V projection: 5120 → 1280 (8 heads)
  - Total: 5120 + 1280 + 1280 = 7680 ✓
```

### **Architecture Mapping**
```yaml
Model Classification:
  - Name: "Phi-4 variant" or "Mibera custom"
  - Base: PHI4-style GQA architecture
  - Loader: phi2 (legacy compatibility)
  - Attention: Grouped Query (8 groups)
  - Size: 14.66B parameters
```

---

## 🛠️ **SOLUTION STRATEGIES**

### **Strategy 1: PHI3 Loader Modification**
```cpp
// Modify PHI3 case to handle GQA tensors
case LLM_ARCH_PHI3:
    // Check if model uses GQA
    if (n_embd_k_gqa != n_embd) {
        // GQA path: adjust QKV tensor expectations
        layer.wqkv = create_tensor(tn(LLM_TENSOR_ATTN_QKV, "weight", i), 
                                  {n_embd, n_embd + 2*n_embd_k_gqa}, 0);
    } else {
        // Standard MHA path
        layer.wqkv = create_tensor(tn(LLM_TENSOR_ATTN_QKV, "weight", i), 
                                  {n_embd, 3*n_embd}, 0);
    }
```

### **Strategy 2: PHI2 Loader Enhancement**
```cpp
// Enhance existing PHI2 case with GQA support
case LLM_ARCH_PHI2:
    // Calculate actual QKV dimensions from metadata
    int64_t expected_qkv_dim = n_embd + 2*n_embd_k_gqa;
    
    layer.wqkv = create_tensor(tn(LLM_TENSOR_ATTN_QKV, "weight", i), 
                              {n_embd, expected_qkv_dim}, 
                              TENSOR_NOT_REQUIRED);
```

### **Strategy 3: Dynamic Architecture Detection**
```cpp
// Auto-detect architecture based on tensor shapes
auto detect_attention_type(const gguf_context * ctx) {
    // Read first QKV tensor shape
    auto qkv_shape = get_tensor_shape(ctx, "blk.0.attn_qkv.weight");
    int64_t qkv_dim = qkv_shape[1];
    int64_t embd_dim = qkv_shape[0];
    
    if (qkv_dim == embd_dim * 3) {
        return ATTENTION_MHA;  // Standard multi-head
    } else if (qkv_dim < embd_dim * 2) {
        return ATTENTION_GQA;  // Grouped query
    }
    return ATTENTION_UNKNOWN;
}
```

---

## 🌟 **BREAKTHROUGH SMALL LANGUAGE MODELS 2024-2025**

### **Microsoft PHI Series**
```yaml
PHI-4 (14B):
  - Specializes in complex reasoning
  - 9.8 trillion token training
  - State-of-the-art math performance
  - GGUF available: ✅

PHI-4-mini (3.8B):
  - 200K vocabulary (multilingual)
  - Grouped Query Attention
  - Function calling built-in
  - Shared embedding optimization

PHI-4-multimodal (5.6B):
  - Text + Image + Audio support
  - Advanced encoders/adapters
  - Multimodal reasoning
```

### **Alibaba Qwen2.5 Series**
```yaml
Qwen2.5-Coder (32B):
  - Code generation specialist
  - Code reasoning & fixing
  - GGUF format available
  - Multiple size variants: 0.5B-32B

Key Features:
  - Speed optimized for local deployment
  - Lightweight variants (0.5B perfect for apps)
  - Strong practical performance
```

### **Google Gemma2 Series**
```yaml
Gemma2 (2B):
  - 2 billion parameters
  - Optimized for local deployment
  - Real-time applications focus
  - Text generation & translation

Gemma2 (27B):
  - Large option with enhanced capabilities
  - GGUF format support
  - Built with Gemini research
```

### **Hugging Face SmolLM Series**
```yaml
SmolLM3 (3B):
  - 6 language support
  - Advanced reasoning
  - Long context capability
  - Fully open source

SmolLM2 variants:
  - 135M: Ultra-lightweight (pip installable!)
  - 360M: Balanced performance  
  - 1.7B: Most capable variant
  - Blazingly fast inference
```

---

## 🔍 **LLAMA.CPP DEBUGGING GUIDE**

### **Common Tensor Shape Errors**
```yaml
Error Types:
  1. "tensor X has wrong shape; expected A, B, got C, D"
     - Architecture mismatch
     - GQA vs MHA confusion
     - Model conversion issues
     
  2. "tensor X not found"
     - Missing tensors in conversion
     - Incomplete model files
     - Architecture loader mismatch
     
  3. "missing tensor weight"
     - Bias tensors missing (✅ SOLVED for Mibera)
     - Norm weight issues
     - Conversion artifacts
```

### **Debugging Solutions**
```yaml
1. Update llama.cpp:
   - Many issues resolved in newer versions
   - Check GitHub issues for specific errors
   
2. Verify Model Format:
   - Ensure GGUF vs GGML compatibility
   - Validate conversion process
   
3. Check Architecture Parameters:
   - Verify metadata matches actual structure
   - Confirm attention mechanism type
   
4. Use Correct CLI Parameters:
   - --gqa flag for grouped query attention
   - Model-specific parameters
   
5. Validate Conversion:
   - Re-convert from original model
   - Check tensor shapes in source
```

### **Architecture Detection Debugging**
```bash
# Check model metadata
./llama-cli --model model.gguf --print-meta

# Verbose loading for debugging  
./llama-cli --model model.gguf --verbose

# Architecture-specific parameters
./llama-cli --model model.gguf --gqa 8  # For 8-group GQA
```

---

## 📈 **NEXT STEPS FOR MIBERA**

### **Immediate Actions**
1. **✅ COMPLETED**: Bias tensor patch (all PHI2 bias tensors optional)
2. **🔄 IN PROGRESS**: QKV tensor dimension analysis
3. **📋 TODO**: Implement GQA-aware tensor loading

### **Implementation Plan**
```yaml
Phase 1: Architecture Detection
  - Analyze Mibera's actual attention mechanism
  - Confirm GQA group count (likely 8)
  - Validate head count ratios

Phase 2: Loader Modification  
  - Modify PHI2 loader for GQA support
  - Add dynamic tensor shape calculation
  - Implement fallback mechanisms

Phase 3: Testing & Validation
  - Test Q2_K model loading
  - Verify inference quality
  - Performance benchmarking

Phase 4: Documentation
  - Update conversion guides
  - Create GQA troubleshooting docs
  - Share solution with community
```

### **Technical Implementation**
```cpp
// Proposed llama-model.cpp modification for PHI2 GQA support
case LLM_ARCH_PHI2:
    {
        // Detect if model uses GQA by checking metadata or tensor shapes
        const int64_t expected_kv_heads = hparams.n_head_kv > 0 ? hparams.n_head_kv : hparams.n_head;
        const int64_t n_embd_k_gqa = (n_embd / hparams.n_head) * expected_kv_heads;
        const int64_t qkv_proj_size = n_embd + 2 * n_embd_k_gqa;
        
        for (int i = 0; i < n_layer; ++i) {
            auto & layer = layers[i];
            
            // Use calculated QKV projection size instead of hardcoded 3*n_embd
            layer.wqkv = create_tensor(tn(LLM_TENSOR_ATTN_QKV, "weight", i), 
                                      {n_embd, qkv_proj_size}, TENSOR_NOT_REQUIRED);
            layer.bqkv = create_tensor(tn(LLM_TENSOR_ATTN_QKV, "bias", i), 
                                      {qkv_proj_size}, TENSOR_NOT_REQUIRED);
            
            // Handle split Q/K/V if QKV not available
            if (layer.wqkv == nullptr) {
                layer.wq = create_tensor(tn(LLM_TENSOR_ATTN_Q, "weight", i), {n_embd, n_embd}, 0);
                layer.bq = create_tensor(tn(LLM_TENSOR_ATTN_Q, "bias", i), {n_embd}, TENSOR_NOT_REQUIRED);
                
                layer.wk = create_tensor(tn(LLM_TENSOR_ATTN_K, "weight", i), {n_embd, n_embd_k_gqa}, 0);
                layer.bk = create_tensor(tn(LLM_TENSOR_ATTN_K, "bias", i), {n_embd_k_gqa}, TENSOR_NOT_REQUIRED);
                
                layer.wv = create_tensor(tn(LLM_TENSOR_ATTN_V, "weight", i), {n_embd, n_embd_k_gqa}, 0);
                layer.bv = create_tensor(tn(LLM_TENSOR_ATTN_V, "bias", i), {n_embd_k_gqa}, TENSOR_NOT_REQUIRED);
            }
        }
    } break;
```

---

## 🎯 **CONCLUSION**

### **Key Findings**
1. **✅ Bias Issue Solved**: Complete PHI2 bias tensor patch successful
2. **🔍 Architecture Identified**: Mibera uses PHI4-style GQA (8 groups)  
3. **📐 Tensor Mismatch Explained**: GQA reduces QKV dimensions from 15360 → 7680
4. **🛠️ Solution Path Clear**: Modify PHI2 loader for GQA support

### **Impact Assessment**
- **Memory Efficiency**: GQA provides 4x KV cache reduction
- **Performance**: Faster inference with maintained quality  
- **Compatibility**: Requires loader modification for full support
- **Future**: Aligns with industry trend toward efficient attention mechanisms

### **Success Metrics**
- ✅ Model loads without bias errors
- ✅ Architecture correctly identified  
- ✅ Tensor dimensions analyzed
- 🔄 QKV mismatch solution in progress
- 📋 Full inference testing pending

---

*This research document provides the foundation for resolving Mibera's architectural compatibility with llama.cpp and represents a comprehensive analysis of modern small language model architectures.*
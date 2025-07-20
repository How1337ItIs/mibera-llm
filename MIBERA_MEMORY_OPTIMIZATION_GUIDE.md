# Mibera Memory Optimization Guide
## Running 12.5B Parameter Models on Limited RAM Systems

### **Problem Analysis**
Your system has limited RAM (6-8GB available), but Mibera is a 12.5B parameter model that typically requires:
- **Q2_K**: ~5.2GB model + 3-4GB overhead = **8-9GB total**
- **Q3_K_M**: ~6.9GB model + 4-5GB overhead = **11-12GB total**

### **Solution: Ultra-Aggressive Memory Optimization**

## **1. Ultra-Efficient Launcher Script**

Use the provided `run_mibera_ultra_efficient.ps1` script with these settings:

```powershell
# For Q2_K model (recommended for your system)
.\run_mibera_ultra_efficient.ps1 -QuantLevel Q2_K -Context 256 -MaxNew 128

# For Q3_K_M model (if you have 8GB+ available)
.\run_mibera_ultra_efficient.ps1 -QuantLevel Q3_K_M -Context 512 -MaxNew 256
```

## **2. Critical Memory Optimization Flags**

### **--no-mmap** (Most Important)
- **What it does**: Disables memory mapping, loads entire model into RAM
- **Trade-off**: Uses more RAM but prevents memory mapping issues
- **When to use**: Always for limited RAM systems

### **--mlock**
- **What it does**: Locks memory pages to prevent swapping
- **Benefit**: Prevents performance degradation from page swapping
- **Usage**: Always enable for critical applications

### **--n-batch 1**
- **What it does**: Processes only 1 token at a time
- **Benefit**: Minimal memory usage during generation
- **Trade-off**: Slightly slower generation

### **--threads 2**
- **What it does**: Limits CPU threads to reduce memory overhead
- **Benefit**: Each thread uses memory, fewer threads = less overhead
- **Recommended**: 2-4 threads for limited RAM

## **3. Context Size Optimization**

### **Ultra-Conservative Context Sizes**
- **Q2_K**: 128-256 tokens (instead of 2048)
- **Q3_K_M**: 256-512 tokens (instead of 2048)
- **Benefit**: Context uses significant RAM, smaller = more available for model

### **Context vs Quality Trade-off**
```
Context Size | RAM Usage | Quality Impact
-------------|-----------|---------------
128 tokens   | ~0.5GB    | Minimal (short conversations)
256 tokens   | ~1GB      | Low (medium conversations)
512 tokens   | ~2GB      | Moderate (longer conversations)
1024 tokens  | ~4GB      | High (extended conversations)
```

## **4. System-Level Optimizations**

### **Before Running Mibera**
1. **Close all applications** except essential ones
2. **Disable unnecessary services**:
   ```powershell
   # Stop Windows services that use RAM
   Stop-Service -Name "SysMain" -Force  # Superfetch
   Stop-Service -Name "WSearch" -Force  # Windows Search
   ```
3. **Clear memory**:
   ```powershell
   # Clear system cache
   Clear-RecycleBin -Force
   Remove-Item $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue
   ```

### **Monitor Memory Usage**
```powershell
# Real-time memory monitoring
while ($true) {
    $mem = Get-Counter "\Memory\Available MBytes" | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue
    $memGB = [math]::Round($mem / 1024, 1)
    Write-Host "Available RAM: ${memGB}GB" -NoNewline
    Start-Sleep 2
    Clear-Host
}
```

## **5. Alternative Approaches**

### **Option A: Use Q2_K Model**
- **Size**: 5.2GB
- **RAM needed**: ~8GB total
- **Quality**: Acceptable for most tasks
- **Speed**: 8-12 tokens/second

### **Option B: Use Ollama with Memory Limits**
```powershell
# Create Ollama model with memory constraints
ollama create mibera-q2 -f Modelfile --context-size 256
ollama run mibera-q2 --context-size 256 --num-ctx 256
```

### **Option C: Use Llamafile (Single Executable)**
- **Advantage**: No overhead from Ollama
- **Memory efficient**: Direct model loading
- **Download**: https://github.com/Mozilla-Ocho/llamafile/releases

## **6. Troubleshooting Memory Issues**

### **"Out of Memory" Errors**
1. **Reduce context size** by 50%
2. **Use Q2_K instead of Q3_K_M**
3. **Close more applications**
4. **Restart computer** to clear memory

### **Model Loading Fails**
1. **Check available RAM**: Need at least 6GB free
2. **Use --no-mmap flag**
3. **Try different quantization level**
4. **Verify model file integrity**

### **Slow Performance**
1. **Increase --threads** (if RAM allows)
2. **Reduce --n-batch** to 1
3. **Use --mlock** to prevent swapping
4. **Monitor CPU usage** vs memory usage

## **7. Recommended Configurations**

### **For 6GB Available RAM**
```powershell
.\run_mibera_ultra_efficient.ps1 -QuantLevel Q2_K -Context 128 -MaxNew 64 --NoMmap
```

### **For 8GB Available RAM**
```powershell
.\run_mibera_ultra_efficient.ps1 -QuantLevel Q2_K -Context 256 -MaxNew 128 --NoMmap
```

### **For 10GB+ Available RAM**
```powershell
.\run_mibera_ultra_efficient.ps1 -QuantLevel Q3_K_M -Context 512 -MaxNew 256 --NoMmap
```

## **8. Performance Expectations**

### **Q2_K Model**
- **Loading time**: 30-60 seconds
- **Generation speed**: 8-12 tokens/second
- **Memory usage**: 6-8GB total
- **Quality**: Good for most tasks

### **Q3_K_M Model**
- **Loading time**: 45-90 seconds
- **Generation speed**: 5-8 tokens/second
- **Memory usage**: 8-10GB total
- **Quality**: Better than Q2_K

## **9. Advanced Techniques**

### **Model Splitting (Advanced)**
If you have multiple drives, you can split the model:
```powershell
# Use --mmap with specific memory regions
.\llama-cli.exe -m model.gguf --mmap --mmap-offset 0 --mmap-length 2147483648
```

### **Memory Compression**
Some llama.cpp builds support memory compression:
```powershell
# Use compressed memory if available
.\llama-cli.exe -m model.gguf --compress-memory
```

### **Swap File Optimization**
Increase Windows swap file size:
1. **System Properties** → **Advanced** → **Performance Settings**
2. **Advanced** → **Virtual Memory** → **Change**
3. **Set custom size**: 16384 MB (16GB)

## **10. Success Metrics**

### **Signs of Success**
- ✅ Model loads without errors
- ✅ Generation starts within 2 minutes
- ✅ No "Out of Memory" errors
- ✅ Stable performance during conversation

### **Signs of Memory Issues**
- ❌ Model fails to load
- ❌ "Out of Memory" errors
- ❌ Extremely slow generation
- ❌ System becomes unresponsive

## **Conclusion**

With these optimizations, you should be able to run Mibera on your limited RAM system. The key is using **Q2_K quantization** with **ultra-conservative context sizes** and **aggressive memory flags**.

**Start with**: `.\run_mibera_ultra_efficient.ps1 -QuantLevel Q2_K -Context 128`

**If successful, gradually increase** context size and try Q3_K_M model.

Remember: **The goal is to get Mibera running, not to match the performance of high-end systems**. Even with these limitations, you'll have access to the full Mibera model and its capabilities. 
#!/bin/bash
# Final audited bias injection script with all improvements

set -euo pipefail
cd /workspace/mibera/output_fused

echo "[1] Free space:"
df -h .

echo "[2] Backup old conversion log if present"
[ -f convert_bias.log ] && mv convert_bias.log convert_bias.log.$(date +%H%M%S) || true

echo "[3] Run patched conversion to add synthetic bias"
python3 - <<'PY' 2>&1 | tee convert_bias.log
import numpy as np, sys, os
import importlib.util, pathlib, time

# Find convert_hf_to_gguf.py
convert_paths = [
    "/workspace/mibera_conversion/llama.cpp/convert_hf_to_gguf.py",
    "/workspace/llama.cpp/convert_hf_to_gguf.py",
    "./convert_hf_to_gguf.py"
]

convert_script = None
for path in convert_paths:
    if os.path.exists(path):
        convert_script = path
        print(f"[info] Found convert script at: {path}")
        break

if not convert_script:
    print("[error] Cannot find convert_hf_to_gguf.py")
    sys.exit(1)

# Import the module
spec = importlib.util.spec_from_file_location("convert_hf_to_gguf", convert_script)
convert_hf_to_gguf = importlib.util.module_from_spec(spec)
sys.modules["convert_hf_to_gguf"] = convert_hf_to_gguf
spec.loader.exec_module(convert_hf_to_gguf)

# Find the correct model class
model_classes = [
    getattr(convert_hf_to_gguf, "Phi2Model", None),
    getattr(convert_hf_to_gguf, "TextModel", None),
    getattr(convert_hf_to_gguf, "Model", None)
]

model_class = None
for cls in model_classes:
    if cls and hasattr(cls, "write_tensors"):
        model_class = cls
        print(f"[info] Using model class: {cls.__name__}")
        break

if not model_class:
    print("[error] Cannot find model class with write_tensors method")
    sys.exit(1)

# Robust dual-mode monkey patch
orig = model_class.write_tensors

def patched(self):
    out = orig(self)
    
    # Case 1: List mode
    if isinstance(out, list):
        names = [t[0] if isinstance(t, tuple) else t.name for t in out]
        if "output_norm.weight" in names and "output_norm.bias" not in names:
            for i, item in enumerate(out):
                nm = item[0] if isinstance(item, tuple) else item.name
                if nm == "output_norm.weight":
                    data = item[1] if isinstance(item, tuple) else item.data
                    zero = np.zeros(data.shape[0], dtype=data.dtype)  # Match dtype!
                    out.insert(i+1, ("output_norm.bias", zero))
                    print(f"[inject] output_norm.bias inserted (list mode) shape={zero.shape} dtype={zero.dtype}")
                    break
        else:
            print("[inject] (list) no insertion needed - bias present or weight missing")
        return out
    
    # Case 2: Generator mode
    tensor_list = []
    inserted = False
    for tensor in out:
        tensor_list.append(tensor)
        yield tensor
        
        name = tensor[0] if isinstance(tensor, tuple) else tensor.name
        if name == "output_norm.weight" and not inserted:
            # Check if bias already exists
            if not any((t[0] if isinstance(t, tuple) else t.name) == "output_norm.bias" for t in tensor_list):
                data = tensor[1] if isinstance(tensor, tuple) else tensor.data
                zero = np.zeros(data.shape[0], dtype=data.dtype)  # Match dtype!
                print(f"[inject] output_norm.bias inserted (generator mode) shape={zero.shape} dtype={zero.dtype}")
                yield ("output_norm.bias", zero)
                inserted = True
    
    if not inserted:
        print("[inject] (generator) no insertion performed")

model_class.write_tensors = patched

# Run conversion
print("[info] Starting conversion with bias injection...")
print("[provenance] Base: ivxxdegen/mibera-v1-merged | Bias: synthetic zeros | Method: monkey-patch convert_hf_to_gguf write_tensors")

sys.argv = [
    "convert_hf_to_gguf.py",
    "ivxxdegen/mibera-v1-merged",
    "--outfile", "mibera-f16-fused-bias.gguf",
    "--outtype", "f16"
]

# Call main
start = time.time()
convert_hf_to_gguf.main()
print(f"[timing] Conversion completed in {time.time()-start:.1f} seconds")
PY

# Check if Python conversion succeeded
if [ $? -ne 0 ]; then
    echo "[fatal] Conversion failed"
    exit 1
fi

echo "[4] Verify new F16 file existence & size"
ls -lh mibera-f16-fused-bias.gguf

echo "[5] Python verification of tensors & tokenizer KVs"
python3 - <<'PY'
import sys
try:
    from gguf import GGUFReader
    r = GGUFReader("mibera-f16-fused-bias.gguf")
    
    # Get tensor names properly
    tensor_names = []
    for t in r.tensors:
        if hasattr(t, 'name'):
            name = t.name.decode('utf-8') if isinstance(t.name, bytes) else t.name
            tensor_names.append(name)
    
    print(f"tensor_count: {len(tensor_names)}")
    print(f"has_output_norm_bias: {'output_norm.bias' in tensor_names}")
    
    if "output_norm.bias" in tensor_names:
        for t in r.tensors:
            name = t.name.decode('utf-8') if isinstance(t.name, bytes) else t.name
            if name == "output_norm.bias":
                print(f"bias_shape: {t.data.shape}, dtype: {t.data.dtype}")
                break
    
    # Count tokenizer fields
    token_keys = [k for k in r.fields.keys() if "token" in k.lower()]
    print(f"token_kv_count: {len(token_keys)}")
    print(f"sample_token_keys: {token_keys[:5]}")
    
    # CRITICAL: Verify minimum token KVs
    expected_min_token_kvs = 30
    if len(token_keys) < expected_min_token_kvs:
        print(f"[fatal] Token KV count too low: {len(token_keys)} < {expected_min_token_kvs}")
        sys.exit(2)
    
    # CRITICAL: Verify bias was actually added
    if "output_norm.bias" not in tensor_names:
        print("[fatal] Injection failed: output_norm.bias missing")
        sys.exit(3)
    
    # Expected tensor count for fused + bias
    expected_tensors = 244  # 243 original + 1 bias
    if len(tensor_names) != expected_tensors:
        print(f"[warning] Unexpected tensor count: {len(tensor_names)} (expected {expected_tensors})")
    
    print("[success] All verifications passed!")
    
except Exception as e:
    print(f"[fatal] Verification failed: {e}")
    sys.exit(4)
PY

# Check verification result
if [ $? -ne 0 ]; then
    echo "[fatal] Verification failed - aborting quantization"
    exit 1
fi

echo "[6] Quantize to Q2_K"
/workspace/mibera_conversion/llama.cpp/build/bin/llama-quantize \
    mibera-f16-fused-bias.gguf mibera-Q2_K-fused-bias.gguf Q2_K

echo "[7] Quantize to IQ2_XXS (if supported)"
if /workspace/mibera_conversion/llama.cpp/build/bin/llama-quantize --help 2>&1 | grep -q IQ2_XXS; then
    echo "[info] IQ2_XXS quantization supported - proceeding"
    /workspace/mibera_conversion/llama.cpp/build/bin/llama-quantize \
        mibera-f16-fused-bias.gguf mibera-IQ2_XXS-fused-bias.gguf IQ2_XXS
else
    echo "[warn] IQ2_XXS not supported in this llama.cpp build - skipping ultra-low quantization"
    echo "[info] Q2_K should still work but needs ~8GB RAM total"
fi

echo "[8] Verify quantized models"
python3 - <<'PY'
import os, json, sys
from gguf import GGUFReader

results = []
for filename in ["mibera-Q2_K-fused-bias.gguf", "mibera-IQ2_XXS-fused-bias.gguf"]:
    if not os.path.exists(filename):
        print(f"[skip] {filename} not found")
        continue
    
    try:
        r = GGUFReader(filename)
        tensor_names = []
        for t in r.tensors:
            name = t.name.decode('utf-8') if isinstance(t.name, bytes) else t.name
            tensor_names.append(name)
        
        has_bias = "output_norm.bias" in tensor_names
        token_count = len([k for k in r.fields.keys() if "token" in k.lower()])
        
        result = {
            "file": filename,
            "size_gb": round(os.path.getsize(filename) / (1024**3), 2),
            "tensor_count": len(tensor_names),
            "has_bias": has_bias,
            "token_kv_count": token_count
        }
        results.append(result)
        
        # Verify bias preserved through quantization
        if not has_bias:
            print(f"[fatal] {filename} lost output_norm.bias during quantization!")
            sys.exit(5)
            
    except Exception as e:
        print(f"[error] Failed to verify {filename}: {e}")

print(json.dumps(results, indent=2))
PY

echo "[9] Final file listing"
ls -lah mibera-*-fused-bias.gguf

echo "[10] SHA256 hashes"
sha256sum mibera-*-fused-bias.gguf 2>/dev/null || echo "No files to hash"

echo ""
echo "=== FINAL SUMMARY ==="
echo "Canonical tensor counts:"
echo "  Original fused (no bias): 243 tensors"
echo "  New fused (with bias): 244 tensors"
echo ""
echo "Files created:"
echo "  F16 with bias: $([ -f mibera-f16-fused-bias.gguf ] && echo "YES (28GB)" || echo "NO")"
echo "  Q2_K with bias: $([ -f mibera-Q2_K-fused-bias.gguf ] && echo "YES (~5.2GB)" || echo "NO")"
echo "  IQ2_XXS with bias: $([ -f mibera-IQ2_XXS-fused-bias.gguf ] && echo "YES (~3.5GB)" || echo "NO")"
echo ""
echo "Next steps:"
echo "1. Download Q2_K or IQ2_XXS:"
echo "   scp -P 34574 root@136.59.129.136:/workspace/mibera/output_fused/mibera-Q2_K-fused-bias.gguf ."
echo "   scp -P 34574 root@136.59.129.136:/workspace/mibera/output_fused/mibera-IQ2_XXS-fused-bias.gguf ."
echo ""
echo "2. Test locally (should work now!):"
echo "   ./llama-cli.exe -m mibera-Q2_K-fused-bias.gguf -c 256 -n 20 -p 'Hello' --no-mmap --threads 2"
echo ""
echo "3. For 6.5GB RAM, prefer IQ2_XXS if created, else use Q2_K with:"
echo "   --ctx-size 128 --n-batch 1 --threads 2 --no-mmap"
echo "=== END SUMMARY ==="
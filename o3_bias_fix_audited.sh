#!/bin/bash
# Audited and fixed version of O3's bias injection script

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

# Find the correct model class (might be Phi2Model instead of TextModel)
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

# Monkey patch to inject bias
orig = model_class.write_tensors

def patched(self):
    # Call original method - returns None, tensors are yielded
    # We need to intercept the generator
    tensor_list = []
    
    # Capture tensors from generator
    for tensor in orig(self):
        tensor_list.append(tensor)
        yield tensor
    
    # Check if we need to inject bias
    names = [t[0] if isinstance(t, tuple) else t.name for t in tensor_list]
    
    if "output_norm.weight" in names and "output_norm.bias" not in names:
        # Find output_norm.weight to get shape
        for item in tensor_list:
            name = item[0] if isinstance(item, tuple) else item.name
            if name == "output_norm.weight":
                # Get tensor data
                data = item[1] if isinstance(item, tuple) else item.data
                # Create zero bias with same width
                zero = np.zeros(data.shape[0], dtype=np.float32)
                print(f"[inject] Adding synthetic output_norm.bias shape={zero.shape}")
                # Yield the bias tensor
                yield ("output_norm.bias", zero)
                break
    else:
        print("[inject] Bias already present or weight missing; no injection")

model_class.write_tensors = patched

# Run conversion
print("[info] Starting conversion with bias injection...")
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

echo "[4] Verify new F16 file existence & size"
ls -lh mibera-f16-fused-bias.gguf

echo "[5] Python verification of tensors & tokenizer KVs"
python3 - <<'PY'
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
    
except Exception as e:
    print(f"[error] Verification failed: {e}")
PY

echo "[6] Quantize to Q2_K"
/workspace/mibera_conversion/llama.cpp/build/bin/llama-quantize \
    mibera-f16-fused-bias.gguf mibera-Q2_K-fused-bias.gguf Q2_K

echo "[7] Quantize to IQ2_XXS (if supported)"
if /workspace/mibera_conversion/llama.cpp/build/bin/llama-quantize --help 2>&1 | grep -q IQ2_XXS; then
    /workspace/mibera_conversion/llama.cpp/build/bin/llama-quantize \
        mibera-f16-fused-bias.gguf mibera-IQ2_XXS-fused-bias.gguf IQ2_XXS
else
    echo "[warn] IQ2_XXS not supported in this build - skipping"
fi

echo "[8] Final file listing"
ls -lah mibera-*-fused-bias.gguf

echo "[9] SHA256 hashes"
sha256sum mibera-*-fused-bias.gguf 2>/dev/null || echo "No files to hash"

echo ""
echo "=== FINAL SUMMARY ==="
echo "F16 with bias created: $([ -f mibera-f16-fused-bias.gguf ] && echo YES || echo NO)"
echo "Q2_K with bias created: $([ -f mibera-Q2_K-fused-bias.gguf ] && echo YES || echo NO)"
echo "IQ2_XXS with bias created: $([ -f mibera-IQ2_XXS-fused-bias.gguf ] && echo YES || echo NO)"
echo ""
echo "Next steps:"
echo "1. Download Q2_K: scp -P 34574 root@136.59.129.136:/workspace/mibera/output_fused/mibera-Q2_K-fused-bias.gguf ."
echo "2. Test locally: ./llama-cli.exe -m mibera-Q2_K-fused-bias.gguf -c 128 -n 10 -p 'Hello'"
echo "=== END SUMMARY ==="
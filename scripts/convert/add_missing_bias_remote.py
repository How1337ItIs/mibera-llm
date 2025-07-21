#!/usr/bin/env python3
"""
Add missing output_norm.bias tensor to Mibera GGUF models
This fixes the llama.cpp loading issue
"""

import struct
import numpy as np
from pathlib import Path

def read_gguf_header(file_path):
    """Read GGUF header to understand structure"""
    with open(file_path, 'rb') as f:
        # Read magic number
        magic = f.read(4)
        if magic != b'GGUF':
            raise ValueError("Not a GGUF file")
        
        # Read version
        version = struct.unpack('<I', f.read(4))[0]
        print(f"GGUF version: {version}")
        
        # Read tensor count and metadata KV count
        tensor_count = struct.unpack('<Q', f.read(8))[0]
        metadata_kv_count = struct.unpack('<Q', f.read(8))[0]
        
        print(f"Tensors: {tensor_count}, Metadata KV: {metadata_kv_count}")
        
        return version, tensor_count, metadata_kv_count

def add_bias_tensor_script():
    """Generate script to add bias tensor on remote"""
    script = '''#!/usr/bin/env python3
import sys
import os
import numpy as np
import struct
import shutil
from pathlib import Path

# Install gguf if needed
try:
    import gguf
except ImportError:
    print("Installing gguf...")
    os.system("pip install gguf")
    import gguf

def add_output_norm_bias(input_path, output_path):
    """Add missing output_norm.bias tensor"""
    print(f"Reading {input_path}...")
    
    reader = gguf.GGUFReader(input_path)
    writer = gguf.GGUFWriter(output_path, reader.header.name, use_temp_file=False)
    
    # Copy all metadata
    for key, field in reader.fields.items():
        writer.add_field(key, field)
    
    # Get embedding dimension for bias size
    embd_dim = 5120  # Phi-4 embedding dimension
    if "phi2.embedding_length" in reader.fields:
        embd_dim = reader.fields["phi2.embedding_length"]
    
    print(f"Embedding dimension: {embd_dim}")
    
    # Copy existing tensors
    bias_added = False
    for tensor in reader.tensors:
        name = tensor.name.decode() if isinstance(tensor.name, bytes) else tensor.name
        writer.add_tensor(name, tensor.data, tensor.shape)
        
        # After output_norm.weight, add output_norm.bias
        if name == "output_norm.weight" and not bias_added:
            print("Adding output_norm.bias...")
            bias_data = np.zeros(embd_dim, dtype=np.float32)
            writer.add_tensor("output_norm.bias", bias_data, [embd_dim])
            bias_added = True
    
    # If we didn't find output_norm.weight, add bias at the end
    if not bias_added:
        print("Adding output_norm.bias at end...")
        bias_data = np.zeros(embd_dim, dtype=np.float32)
        writer.add_tensor("output_norm.bias", bias_data, [embd_dim])
    
    writer.write_header_to_file()
    writer.write_kv_data_to_file()
    writer.write_tensors_to_file()
    writer.close()
    
    print(f"Fixed model saved to: {output_path}")

def main():
    if len(sys.argv) < 2:
        models = ["mibera-Q2_K-final.gguf", "mibera-Q3_K_M-final.gguf", "mibera-IQ2_XXS-ultra.gguf"]
    else:
        models = sys.argv[1:]
    
    for model in models:
        if not os.path.exists(model):
            print(f"Skipping {model} - not found")
            continue
            
        output = model.replace(".gguf", "-fixed.gguf")
        print(f"\\nFixing {model} -> {output}")
        
        try:
            add_output_norm_bias(model, output)
            print(f"[OK] Successfully fixed {model}")
        except Exception as e:
            print(f"[ERROR] Failed to fix {model}: {e}")

if __name__ == "__main__":
    main()
'''
    
    return script

def main():
    print("=== CREATING BIAS FIX SCRIPT ===")
    
    script_content = add_bias_tensor_script()
    
    # Save script locally
    with open("fix_bias_remote.py", "w") as f:
        f.write(script_content)
    
    print("Created fix_bias_remote.py")
    print("\nTo use:")
    print("1. Upload to remote: scp fix_bias_remote.py root@remote:/workspace/mibera/output_fused/")
    print("2. Run on remote: python3 fix_bias_remote.py")
    print("3. Download fixed models")
    
    # Also create upload command
    upload_cmd = f"""
# Upload and run bias fix
scp -i ~/.ssh/vastai_ed25519 -P 34574 fix_bias_remote.py root@136.59.129.136:/workspace/mibera/output_fused/
ssh -i ~/.ssh/vastai_ed25519 -p 34574 root@136.59.129.136 "cd /workspace/mibera/output_fused && python3 fix_bias_remote.py"
"""
    
    with open("run_bias_fix.sh", "w") as f:
        f.write(upload_cmd)
    
    print("\nOr run: bash run_bias_fix.sh")

if __name__ == "__main__":
    main()
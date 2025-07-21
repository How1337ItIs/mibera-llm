#!/usr/bin/env python3
"""
GGUF Surgery: Add missing output_norm.bias to existing F16 GGUF
"""
import numpy as np
import struct
import sys
import os
from pathlib import Path

def add_bias_via_surgery(input_file, output_file):
    """Surgically add output_norm.bias to existing GGUF"""
    print(f"[surgery] Reading {input_file}")
    
    # Import gguf
    try:
        import gguf
    except ImportError:
        print("Installing gguf...")
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "gguf"])
        import gguf
    
    # Read source
    reader = gguf.GGUFReader(input_file)
    
    # Get architecture to create writer
    arch = None
    for field in reader.fields.values():
        if hasattr(field, 'name') and field.name == 'general.architecture':
            arch = field.value
            break
    
    if not arch:
        arch = "phi2"  # Default for our model
    
    print(f"[surgery] Architecture: {arch}")
    
    # Create writer
    writer = gguf.GGUFWriter(output_file, arch, use_temp_file=False)
    
    # Copy all metadata fields
    print("[surgery] Copying metadata...")
    for field in reader.fields.values():
        if hasattr(field, 'name') and hasattr(field, 'value'):
            try:
                writer.add_field(field.name, field.value)
            except AttributeError:
                # Try alternative API
                try:
                    parts = field.name.split('.')
                    if len(parts) == 2:
                        writer.add_key_value(parts[0], parts[1], field.value)
                    else:
                        writer.add_key_value(field.name, "", field.value)
                except:
                    print(f"[warn] Skipping field: {field.name}")
    
    # Track tensors
    tensor_count = 0
    bias_added = False
    
    # Copy tensors and inject bias
    print("[surgery] Copying tensors and injecting bias...")
    for tensor in reader.tensors:
        # Get tensor name
        name = tensor.name
        if isinstance(name, bytes):
            name = name.decode('utf-8')
        
        # Add tensor
        writer.add_tensor(name, tensor.data)
        tensor_count += 1
        
        # After output_norm.weight, inject bias
        if name == "output_norm.weight" and not bias_added:
            # Get embedding dimension from weight shape
            embd_dim = tensor.data.shape[0]
            
            # Create zero bias with same dtype as weight
            bias = np.zeros(embd_dim, dtype=tensor.data.dtype)
            
            print(f"[surgery] Injecting output_norm.bias shape={bias.shape} dtype={bias.dtype}")
            writer.add_tensor("output_norm.bias", bias)
            
            bias_added = True
            tensor_count += 1
    
    # Write file
    print(f"[surgery] Writing {tensor_count} tensors...")
    writer.write_header_to_file()
    writer.write_kv_data_to_file()
    writer.write_tensors_to_file()
    writer.close()
    
    print(f"[surgery] Complete! Added bias: {bias_added}")
    print(f"[surgery] Total tensors: {tensor_count} (expect 244 for fused+bias)")
    
    # Verify
    print("[surgery] Verifying output...")
    verifier = gguf.GGUFReader(output_file)
    verify_names = []
    for t in verifier.tensors:
        name = t.name
        if isinstance(name, bytes):
            name = name.decode('utf-8')
        verify_names.append(name)
    
    has_bias = "output_norm.bias" in verify_names
    token_count = len([k for k in verifier.fields.keys() if "token" in str(k).lower()])
    
    print(f"[verify] Output tensors: {len(verify_names)}")
    print(f"[verify] Has output_norm.bias: {has_bias}")
    print(f"[verify] Token KV count: {token_count}")
    
    if not has_bias:
        print("[FATAL] Surgery failed - bias not present in output!")
        sys.exit(1)
    
    print("[SUCCESS] Surgery complete!")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python surgery_add_bias.py input.gguf output.gguf")
        sys.exit(1)
    
    add_bias_via_surgery(sys.argv[1], sys.argv[2])
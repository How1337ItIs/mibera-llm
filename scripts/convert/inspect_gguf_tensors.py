#!/usr/bin/env python3
"""Inspect GGUF tensor structure to understand the format"""

import sys
import os
from pathlib import Path
sys.path.insert(1, str(Path(__file__).parent / 'llama.cpp-mibera' / 'gguf-py'))

import gguf

def inspect_gguf(file_path):
    """Inspect GGUF file structure"""
    print(f"Reading: {file_path}")
    reader = gguf.GGUFReader(file_path)
    
    print(f"\nTotal tensors: {len(reader.tensors)}")
    
    # Look for FFN tensors specifically
    ffn_tensors = []
    for tensor in reader.tensors:
        if "ffn" in tensor.name:
            ffn_tensors.append((tensor.name, tensor.data.shape))
    
    print(f"\nFFN tensors found: {len(ffn_tensors)}")
    for name, shape in ffn_tensors[:10]:  # Show first 10
        print(f"  {name}: {shape}")
    
    # Count by layer
    layers = set()
    for tensor in reader.tensors:
        if "blk." in tensor.name:
            layer_num = tensor.name.split(".")[1]
            layers.add(int(layer_num))
    
    print(f"\nLayers found: {len(layers)} (0-{max(layers) if layers else 0})")
    
    # Check specific problematic tensors
    print(f"\nChecking for fused FFN tensors...")
    for tensor in reader.tensors:
        if tensor.name.endswith("ffn_up.weight"):
            print(f"  {tensor.name}: {tensor.data.shape}")
            if len(tensor.data.shape) == 2 and tensor.data.shape[1] == 35840:
                print(f"    ^ This is a FUSED tensor (35840 = 2*17920)")
    
    # Look for existing gate tensors
    gate_count = 0
    for tensor in reader.tensors:
        if "ffn_gate.weight" in tensor.name:
            gate_count += 1
    
    print(f"\nExisting FFN gate tensors: {gate_count}")
    
    return True

def main():
    file_path = Path("C:/Users/natha/mibera llm/fixed_models/mibera-Q3_K_M-fixed.gguf")
    
    if not file_path.exists():
        print(f"File not found: {file_path}")
        return False
    
    return inspect_gguf(str(file_path))

if __name__ == "__main__":
    main()
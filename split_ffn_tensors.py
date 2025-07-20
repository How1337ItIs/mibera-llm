#!/usr/bin/env python3
"""
Split fused FFN tensors in existing GGUF file to fix tensor count mismatch.
This directly modifies the GGUF without needing the original HF model.
"""

import sys
import os
from pathlib import Path
sys.path.insert(1, str(Path(__file__).parent / 'llama.cpp-mibera' / 'gguf-py'))

import gguf
import numpy as np

def split_ffn_in_gguf(input_path, output_path):
    """Split fused FFN tensors in GGUF file to fix tensor count (243->203)"""
    
    print(f"Reading GGUF: {input_path}")
    reader = gguf.GGUFReader(input_path)
    
    # Get architecture from field data
    arch = "phi2"  # Default for Mibera
    for field in reader.fields:
        if field.name == "general.architecture":
            if hasattr(field.parts, '__iter__'):
                arch = field.parts[0].decode() if field.parts else "phi2"
            else:
                arch = str(field.parts)
            break
    
    # Create new writer
    writer = gguf.GGUFWriter(output_path, arch)
    
    # Copy all metadata
    print("Copying metadata...")
    for field in reader.fields:
        writer.add_string(field.name, str(field.parts[0]) if field.parts else "")
    
    print("Processing tensors...")
    tensors_processed = 0
    tensors_split = 0
    
    for tensor in reader.tensors:
        name = tensor.name
        data = tensor.data
        
        # Check if this is a fused FFN up weight that needs splitting
        if name.endswith("ffn_up.weight") and len(data.shape) == 2:
            shape = data.shape
            print(f"Found FFN tensor: {name} shape: {shape}")
            
            # Check if this looks like a fused tensor (second dim should be ~35840)
            if shape[1] == 35840:  # 2 * 17920
                print(f"Splitting fused FFN tensor: {name}")
                
                # Split into two halves
                half_size = shape[1] // 2  # 17920
                
                # First half = gate, second half = up
                gate_data = data[:, :half_size].copy()
                up_data = data[:, half_size:].copy()
                
                # Create new tensor names
                gate_name = name.replace("ffn_up.weight", "ffn_gate.weight")
                up_name = name  # Keep original name for up
                
                print(f"  -> {gate_name}: {gate_data.shape}")
                print(f"  -> {up_name}: {up_data.shape}")
                
                # Add both tensors
                writer.add_tensor(gate_name, gate_data, raw_dtype=tensor.tensor_type)
                writer.add_tensor(up_name, up_data, raw_dtype=tensor.tensor_type)
                
                tensors_split += 1
            else:
                # Regular FFN up tensor, copy as-is
                writer.add_tensor(name, data, raw_dtype=tensor.tensor_type)
        else:
            # Copy all other tensors as-is
            writer.add_tensor(name, data, raw_dtype=tensor.tensor_type)
        
        tensors_processed += 1
        if tensors_processed % 50 == 0:
            print(f"Processed {tensors_processed} tensors...")
    
    print(f"Writing to: {output_path}")
    writer.write_header_to_file()
    writer.write_kv_data_to_file()
    writer.write_tensors_to_file()
    writer.close()
    
    print(f"\nSummary:")
    print(f"  Total tensors processed: {tensors_processed}")
    print(f"  FFN tensors split: {tensors_split}")
    print(f"  Expected tensor increase: +{tensors_split} (from {203} to {203 + tensors_split})")
    
    # Verify the new file
    print(f"\nVerifying new file...")
    new_reader = gguf.GGUFReader(output_path)
    new_tensor_count = len(new_reader.tensors)
    print(f"New tensor count: {new_tensor_count}")
    
    # Check for gate tensors
    gate_tensors = [t.name for t in new_reader.tensors if "ffn_gate.weight" in t.name]
    print(f"FFN gate tensors found: {len(gate_tensors)}")
    
    return True

def main():
    input_file = Path("C:/Users/natha/mibera llm/fixed_models/mibera-Q3_K_M-fixed.gguf")
    output_file = Path("C:/Users/natha/mibera llm/fixed_models/mibera-Q3_K_M-split.gguf")
    
    if not input_file.exists():
        print(f"ERROR: Input file not found: {input_file}")
        return False
    
    print("=== MIBERA FFN TENSOR SPLITTING ===")
    print(f"Input:  {input_file}")
    print(f"Output: {output_file}")
    print()
    
    try:
        success = split_ffn_in_gguf(str(input_file), str(output_file))
        if success:
            print(f"\nSuccessfully created: {output_file}")
            return True
        else:
            print(f"\nFailed to create: {output_file}")
            return False
    except Exception as e:
        print(f"\nError during splitting: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
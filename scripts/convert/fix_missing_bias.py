#!/usr/bin/env python3
"""
Add missing output_norm.bias tensor to GGUF model
"""
import numpy as np
from gguf import GGUFReader, GGUFWriter
import argparse
import os

def add_missing_bias(input_path, output_path):
    print(f"Reading {input_path}...")
    reader = GGUFReader(input_path)
    
    # Check if output_norm.bias already exists
    tensor_names = []
    for tensor in reader.tensors:
        name = tensor.name if isinstance(tensor.name, str) else tensor.name.decode('utf-8')
        tensor_names.append(name)
    
    if "output_norm.bias" in tensor_names:
        print("output_norm.bias already exists!")
        return False
    
    print(f"Found {len(tensor_names)} tensors")
    print("Missing: output_norm.bias")
    
    # Create writer
    writer = GGUFWriter(output_path, reader.fields["general.architecture"])
    
    # Copy all metadata
    print("Copying metadata...")
    for field in reader.fields:
        writer.add_field(field, reader.fields[field])
    
    # Copy all existing tensors
    print("Copying tensors...")
    for tensor in reader.tensors:
        data = tensor.data
        name = tensor.name if isinstance(tensor.name, str) else tensor.name.decode('utf-8')
        writer.add_tensor(name, data)
    
    # Add missing bias tensor (zeros, size = embedding_length)
    embedding_length = reader.fields.get("phi2.embedding_length", 5120)
    print(f"Adding output_norm.bias (size: {embedding_length})")
    bias_data = np.zeros(embedding_length, dtype=np.float32)
    writer.add_tensor("output_norm.bias", bias_data)
    
    print("Writing file...")
    writer.write_header_to_file()
    writer.write_kv_data_to_file()
    writer.write_tensors_to_file()
    writer.close()
    
    print(f"Fixed model saved to: {output_path}")
    return True

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input", help="Input GGUF file")
    parser.add_argument("output", help="Output GGUF file")
    args = parser.parse_args()
    
    add_missing_bias(args.input, args.output)
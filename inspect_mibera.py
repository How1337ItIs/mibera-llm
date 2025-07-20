#!/usr/bin/env python3
"""
Automated Architecture Inspection for Mibera Model
Verifies config.json matches actual tensor dimensions
"""
import json
import glob
import safetensors
import sys
import re

def inspect_model(model_dir="."):
    """Inspect model architecture and verify config consistency"""
    
    # Find first safetensor file
    pattern = f"{model_dir}/model-*.safetensors"
    safetensor_files = sorted(glob.glob(pattern))
    
    if not safetensor_files:
        print(f"ERROR: No safetensor files found matching {pattern}")
        sys.exit(1)
    
    ckpt = safetensor_files[0]
    print(f"Inspecting: {ckpt}")
    
    # Open and analyze tensors
    with safetensors.safe_open(ckpt, framework="pt") as f:
        # Get embedding dimensions
        if "model.embed_tokens.weight" in f.keys():
            emb_shape = f.get_tensor("model.embed_tokens.weight").shape
            vocab, hidden = emb_shape
        else:
            print("ERROR: Could not find embedding tensor")
            sys.exit(1)
        
        # Find max layer number
        layer_pattern = re.compile(r"model\.layers\.(\d+)\.")
        max_layer = -1
        for name in f.keys():
            m = layer_pattern.match(name)
            if m:
                max_layer = max(max_layer, int(m.group(1)))
        
        # Check for fused QKV projection
        fused = any("qkv_proj" in k for k in f.keys())
    
    print(f"\nDetected architecture:")
    print(f"  hidden_size={hidden}")
    print(f"  vocab_size={vocab}")
    print(f"  num_hidden_layers={max_layer+1}")
    print(f"  fused_qkv={fused}")
    
    # Load and verify config
    config_path = f"{model_dir}/config.json"
    try:
        with open(config_path, 'r') as f:
            cfg = json.load(f)
    except FileNotFoundError:
        print(f"ERROR: {config_path} not found")
        sys.exit(1)
    
    # Check for mismatches
    problems = []
    for k, v in [("hidden_size", hidden), ("vocab_size", vocab), ("num_hidden_layers", max_layer+1)]:
        if cfg.get(k) != v:
            problems.append(f"{k}: config {cfg.get(k)} != actual {v}")
    
    print("\nConfig verification:")
    if problems:
        print("MISMATCHES FOUND:")
        for p in problems:
            print(f"  - {p}")
        sys.exit(1)
    else:
        print("✓ All parameters match!")
        print("\nConfig values:")
        print(f"  hidden_size: {cfg.get('hidden_size')}")
        print(f"  vocab_size: {cfg.get('vocab_size')}")
        print(f"  num_hidden_layers: {cfg.get('num_hidden_layers')}")
        print(f"  architectures: {cfg.get('architectures')}")
        print(f"  model_type: {cfg.get('model_type')}")
        return 0

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Inspect Mibera model architecture")
    parser.add_argument("model_dir", nargs="?", default=".", help="Model directory path")
    args = parser.parse_args()
    
    sys.exit(inspect_model(args.model_dir))
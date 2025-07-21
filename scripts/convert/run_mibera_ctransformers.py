#!/usr/bin/env python3
"""
Run Mibera using ctransformers - more forgiving with model formats
"""

import sys
import os

# Install ctransformers if needed
try:
    from ctransformers import AutoModelForCausalLM
except ImportError:
    print("Installing ctransformers...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "ctransformers"])
    from ctransformers import AutoModelForCausalLM

def run_mibera(model_path, prompt="Hello, I am", max_tokens=50):
    """Run Mibera model using ctransformers"""
    
    print(f"Loading model: {model_path}")
    print("This may take a moment...")
    
    try:
        # Load model with ultra-conservative settings
        model = AutoModelForCausalLM.from_pretrained(
            model_path,
            model_type="phi",  # Try phi type
            gpu_layers=0,      # CPU only for now
            context_length=256,  # Ultra small context
            batch_size=1,      # Minimal batch
            threads=2          # Limited threads
        )
        
        print("[OK] Model loaded successfully!")
        print(f"\nPrompt: {prompt}")
        print("Generating response...")
        
        # Generate response
        response = model(prompt, max_new_tokens=max_tokens, temperature=0.7)
        
        print(f"\nResponse: {response}")
        
        # Interactive mode
        while True:
            user_input = input("\nEnter prompt (or 'quit' to exit): ")
            if user_input.lower() == 'quit':
                break
            
            response = model(user_input, max_new_tokens=max_tokens, temperature=0.7)
            print(f"Response: {response}")
            
    except Exception as e:
        print(f"[ERROR] Error: {e}")
        print("\nTrying alternative model type...")
        
        try:
            # Try with gpt2 type instead
            model = AutoModelForCausalLM.from_pretrained(
                model_path,
                model_type="gpt2",
                gpu_layers=0,
                context_length=256,
                batch_size=1,
                threads=2
            )
            
            print("[OK] Model loaded with gpt2 type!")
            response = model(prompt, max_new_tokens=max_tokens)
            print(f"\nResponse: {response}")
            
        except Exception as e2:
            print(f"[ERROR] Alternative also failed: {e2}")
            print("\nThe model may have compatibility issues.")
            print("Recommendations:")
            print("1. Wait for IQ2_XXS quantization to complete on remote")
            print("2. Try rebuilding models with proper tensor handling")
            print("3. Use a different inference engine")

def main():
    # Model paths
    models = {
        "Q2_K": r"C:\Users\natha\mibera_llm_final\mibera-Q2_K-final.gguf",
        "Q3_K_M": r"C:\Users\natha\mibera_llm_final\mibera-Q3_K_M-final.gguf"
    }
    
    print("=== MIBERA CTRANSFORMERS RUNNER ===")
    print("Using ctransformers for more flexible model loading")
    print()
    
    # Check which models exist
    available = []
    for name, path in models.items():
        if os.path.exists(path):
            size_gb = os.path.getsize(path) / (1024**3)
            print(f"[OK] {name}: {path} ({size_gb:.1f}GB)")
            available.append((name, path))
        else:
            print(f"[X] {name}: Not found")
    
    if not available:
        print("\nNo models found!")
        return
    
    # Use Q2_K by default
    model_name, model_path = available[0]
    print(f"\nUsing {model_name} model")
    
    # Run the model
    run_mibera(model_path)

if __name__ == "__main__":
    main()
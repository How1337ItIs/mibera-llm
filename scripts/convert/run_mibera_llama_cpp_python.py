#!/usr/bin/env python3
"""
Run Mibera using llama-cpp-python
This may be more forgiving with missing tensors
"""

import sys
import os

print("=== MIBERA LLAMA-CPP-PYTHON RUNNER ===")

# Install llama-cpp-python if needed
try:
    from llama_cpp import Llama
except ImportError:
    print("Installing llama-cpp-python...")
    import subprocess
    # Install CPU-only version to avoid CUDA issues
    subprocess.check_call([sys.executable, "-m", "pip", "install", "llama-cpp-python", "--no-cache-dir"])
    from llama_cpp import Llama

def run_mibera_minimal():
    """Try to run Mibera with minimal settings"""
    
    model_path = r"C:\Users\natha\mibera_llm_final\mibera-Q2_K-final.gguf"
    
    if not os.path.exists(model_path):
        print(f"Model not found: {model_path}")
        return
    
    print(f"Loading model: {model_path}")
    print("Using ultra-conservative settings for 6.5GB RAM...")
    
    try:
        # Try with minimal settings
        llm = Llama(
            model_path=model_path,
            n_ctx=128,          # Ultra small context
            n_batch=1,          # Minimal batch
            n_threads=2,        # Limited threads
            n_gpu_layers=0,     # CPU only
            use_mmap=False,     # No memory mapping
            use_mlock=True,     # Lock memory
            verbose=False       # Less output
        )
        
        print("[OK] Model loaded successfully!")
        
        # Test generation
        prompt = "Hello, I am"
        print(f"\nPrompt: {prompt}")
        print("Generating...")
        
        output = llm(prompt, max_tokens=20, temperature=0.7, top_p=0.9)
        print(f"Response: {output['choices'][0]['text']}")
        
        # Interactive mode
        print("\nInteractive mode (type 'quit' to exit):")
        while True:
            user_input = input("\n> ")
            if user_input.lower() == 'quit':
                break
            
            output = llm(user_input, max_tokens=50, temperature=0.7)
            print(f"Mibera: {output['choices'][0]['text']}")
            
    except Exception as e:
        print(f"[ERROR] Failed to load model: {e}")
        
        # Try alternative approach
        print("\nTrying alternative settings...")
        try:
            llm = Llama(
                model_path=model_path,
                n_ctx=64,           # Even smaller
                n_batch=1,
                n_threads=1,        # Single thread
                n_gpu_layers=0,
                use_mmap=True,      # Try with mmap
                use_mlock=False,
                verbose=True        # See what's happening
            )
            print("[OK] Loaded with alternative settings!")
            
        except Exception as e2:
            print(f"[ERROR] Alternative also failed: {e2}")
            print("\nThe missing output_norm.bias tensor is blocking all loaders.")
            print("We need to wait for the IQ quantizations or fix the tensor issue.")

def main():
    print("This uses llama-cpp-python which may handle missing tensors better")
    print("RAM available: ~6.5GB")
    print()
    
    run_mibera_minimal()

if __name__ == "__main__":
    main()
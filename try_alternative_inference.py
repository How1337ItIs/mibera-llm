#!/usr/bin/env python3
"""
Alternative Inference Engines for Mibera
Try different approaches to run the model despite missing tensor
"""

import os
import subprocess
import sys
from pathlib import Path

def check_ollama_alternative():
    """Try Ollama with different model format"""
    print("=== TRYING OLLAMA ALTERNATIVE ===")
    
    # Create a Modelfile that might work better
    modelfile_content = """FROM mibera-Q2_K-final.gguf
TEMPLATE {{"prompt": "{{.Prompt}}", "response": "{{.Response}}"}}
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
PARAMETER num_ctx 256
PARAMETER num_predict 128
"""
    
    with open("Modelfile_alternative", "w") as f:
        f.write(modelfile_content)
    
    print("Created alternative Modelfile")
    print("Try: ollama create mibera-alt -f Modelfile_alternative")
    print("Then: ollama run mibera-alt")

def check_ctransformers():
    """Try ctransformers library"""
    print("=== TRYING CTRANSFORMERS ===")
    
    try:
        import ctransformers
        print("ctransformers available!")
        
        # Create a simple test script
        test_script = '''
import ctransformers
from ctransformers import AutoModelForCausalLM

# Try loading with ctransformers (more forgiving)
try:
    model = AutoModelForCausalLM.from_pretrained(
        "C:/Users/natha/mibera_llm_final/mibera-Q2_K-final.gguf",
        model_type="phi2",
        gpu_layers=0,
        context_length=256
    )
    print("✅ Model loaded with ctransformers!")
    
    # Test generation
    response = model("Hello, I am", max_new_tokens=20)
    print(f"Response: {response}")
    
except Exception as e:
    print(f"❌ ctransformers failed: {e}")
'''
        
        with open("test_ctransformers.py", "w") as f:
            f.write(test_script)
        
        print("Created test_ctransformers.py")
        print("Run: python test_ctransformers.py")
        
    except ImportError:
        print("ctransformers not installed")
        print("Install with: pip install ctransformers")

def check_exllama():
    """Try ExLlama (if available)"""
    print("=== TRYING EXLLAMA ===")
    print("ExLlama is more forgiving with model formats")
    print("Install with: pip install exllama")
    print("Then try loading the model with ExLlama")

def check_llamafile():
    """Try Llamafile"""
    print("=== TRYING LLAMAFILE ===")
    
    # Download llamafile
    llamafile_url = "https://github.com/Mozilla-Ocho/llamafile/releases/latest/download/llamafile-windows-x86_64.exe"
    
    print(f"Downloading llamafile from: {llamafile_url}")
    print("Then try: llamafile.exe mibera-Q2_K-final.gguf")

def create_workaround_script():
    """Create a script to try multiple approaches"""
    script_content = '''#!/usr/bin/env python3
"""
Mibera Workaround Script
Try multiple approaches to run the model
"""

import os
import subprocess
import sys

def try_approach_1():
    """Try with different llama.cpp flags"""
    print("=== APPROACH 1: Different llama.cpp flags ===")
    cmd = [
        "llama-cpp-windows/llama-cli.exe",
        "-m", "C:/Users/natha/mibera_llm_final/mibera-Q2_K-final.gguf",
        "-c", "128",
        "-n", "20",
        "-p", "Hello",
        "--no-mmap",
        "--mlock",
        "--threads", "1"
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        if result.returncode == 0:
            print("✅ Approach 1 worked!")
            return True
        else:
            print(f"❌ Approach 1 failed: {result.stderr}")
            return False
    except Exception as e:
        print(f"❌ Approach 1 error: {e}")
        return False

def try_approach_2():
    """Try with Ollama"""
    print("=== APPROACH 2: Ollama ===")
    try:
        # Create simple modelfile
        with open("simple_modelfile", "w") as f:
            f.write("FROM mibera-Q2_K-final.gguf\\n")
        
        cmd = ["ollama", "create", "mibera-simple", "-f", "simple_modelfile"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Ollama model created!")
            return True
        else:
            print(f"❌ Ollama failed: {result.stderr}")
            return False
    except Exception as e:
        print(f"❌ Ollama error: {e}")
        return False

def try_approach_3():
    """Try with ctransformers"""
    print("=== APPROACH 3: ctransformers ===")
    try:
        import ctransformers
        print("✅ ctransformers available")
        return True
    except ImportError:
        print("❌ ctransformers not installed")
        return False

def main():
    print("=== MIBERA WORKAROUND SCRIPT ===")
    print("Trying multiple approaches to run the model...")
    
    approaches = [
        try_approach_1,
        try_approach_2,
        try_approach_3
    ]
    
    for i, approach in enumerate(approaches, 1):
        print(f"\\n--- Trying Approach {i} ---")
        if approach():
            print(f"✅ Approach {i} succeeded!")
            break
        else:
            print(f"❌ Approach {i} failed")
    
    print("\\n=== RECOMMENDATIONS ===")
    print("1. Rebuild models on remote instance (best solution)")
    print("2. Try different llama.cpp version")
    print("3. Use ctransformers library")
    print("4. Try Ollama with different settings")

if __name__ == "__main__":
    main()
'''
    
    with open("mibera_workaround.py", "w") as f:
        f.write(script_content)
    
    print("Created mibera_workaround.py")
    print("Run: python mibera_workaround.py")

def main():
    print("=== MIBERA ALTERNATIVE INFERENCE OPTIONS ===")
    print("Since the models have missing tensors, let's try alternatives:")
    
    check_ollama_alternative()
    check_ctransformers()
    check_exllama()
    check_llamafile()
    create_workaround_script()
    
    print("\n=== SUMMARY ===")
    print("1. BEST: Rebuild models on remote instance")
    print("2. TRY: ctransformers library (more forgiving)")
    print("3. TRY: Ollama with different settings")
    print("4. TRY: Llamafile (single executable)")
    print("5. TRY: ExLlama (if available)")

if __name__ == "__main__":
    main() 
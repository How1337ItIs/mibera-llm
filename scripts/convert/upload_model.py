# upload_model.py - Upload Mibera model to cloud instance
# Run this on your cloud instance to download the model directly

import os
import sys
from huggingface_hub import snapshot_download

def download_mibera():
    """Download Mibera model directly on cloud instance"""
    
    print("=== MIBERA MODEL DOWNLOAD ===")
    print("Downloading ivxxdegen/mibera-v1-merged directly to cloud instance...")
    
    # Create directory
    os.makedirs("/workspace/mibera/models", exist_ok=True)
    
    try:
        # Download model directly
        model_path = snapshot_download(
            repo_id="ivxxdegen/mibera-v1-merged",
            local_dir="/workspace/mibera/models/mibera",
            resume_download=True
        )
        
        print(f"✓ Model downloaded to: {model_path}")
        
        # Verify files
        import glob
        safetensor_files = glob.glob("/workspace/mibera/models/mibera/*.safetensors")
        print(f"✓ Found {len(safetensor_files)} safetensor files")
        
        if len(safetensor_files) == 13:
            print("✓ All 13 model files present!")
            print("\nReady to run conversion:")
            print("bash convert_mibera.sh")
        else:
            print(f"⚠ Expected 13 files, found {len(safetensor_files)}")
            
        return True
        
    except Exception as e:
        print(f"ERROR: {e}")
        return False

if __name__ == "__main__":
    download_mibera()
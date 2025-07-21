# local_download.py - Download converted models from cloud to local machine
# Run this on your LOCAL machine after cloud conversion

import os
import subprocess
import sys

def download_from_cloud():
    """Download converted GGUF files from cloud instance"""
    
    print("=== DOWNLOAD CONVERTED MODELS ===")
    print("This script helps download the converted GGUF files from your cloud instance")
    print()
    
    # Get cloud instance details
    cloud_ip = input("Enter your vast.ai instance IP (e.g., 1.2.3.4): ").strip()
    cloud_port = input("Enter SSH port (usually 22): ").strip() or "22"
    
    if not cloud_ip:
        print("ERROR: IP address is required!")
        return False
    
    # Create local directory
    local_dir = "C:\\mibera\\models"
    os.makedirs(local_dir, exist_ok=True)
    
    # Files to download
    files_to_download = [
        "mibera-Q2_K.gguf",
        "mibera-Q3_K_M.gguf", 
        "mibera-Q4_K_M.gguf"
    ]
    
    print(f"Downloading to: {local_dir}")
    print()
    
    for filename in files_to_download:
        print(f"Downloading {filename}...")
        
        # SCP command
        remote_path = f"root@{cloud_ip}:/workspace/mibera/output/{filename}"
        local_path = os.path.join(local_dir, filename)
        
        scp_cmd = [
            "scp", 
            "-P", cloud_port,
            "-o", "StrictHostKeyChecking=no",
            remote_path, 
            local_path
        ]
        
        print(f"Command: {' '.join(scp_cmd)}")
        
        try:
            result = subprocess.run(scp_cmd, check=True, capture_output=True, text=True)
            if os.path.exists(local_path):
                size_mb = os.path.getsize(local_path) / (1024*1024)
                print(f"✓ Downloaded {filename} ({size_mb:.1f} MB)")
            else:
                print(f"⚠ Download may have failed for {filename}")
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to download {filename}: {e}")
        except FileNotFoundError:
            print("ERROR: SCP not found. You may need to:")
            print("1. Install Git for Windows (includes SCP)")
            print("2. Use WinSCP or another SCP client")
            print("3. Or download files manually via the vast.ai web interface")
            return False
        
        print()
    
    # Verify downloads
    print("=== DOWNLOAD SUMMARY ===")
    for filename in files_to_download:
        local_path = os.path.join(local_dir, filename)
        if os.path.exists(local_path):
            size_gb = os.path.getsize(local_path) / (1024*1024*1024)
            print(f"✓ {filename}: {size_gb:.2f} GB")
        else:
            print(f"✗ {filename}: Not found")
    
    print()
    print("If downloads completed successfully, you can now run:")
    print("cd C:\\mibera")
    print(".\\run_mibera.ps1 -Mode Mibera")
    
    return True

if __name__ == "__main__":
    download_from_cloud()
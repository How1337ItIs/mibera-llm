# download_mibera.py - Download Q3_K_M + evaluation from cloud

import os
import subprocess
import sys
from pathlib import Path

def download_artifacts():
    """Download Mibera Q3_K_M and evaluation artifacts"""
    
    print("=== MIBERA Q3_K_M DOWNLOAD ===")
    
    # Get connection details
    cloud_ip = input("Cloud instance IP: ").strip()
    cloud_port = input("SSH port (default 22): ").strip() or "22"
    
    if not cloud_ip:
        print("ERROR: IP required")
        return False
    
    # Local paths
    local_models = Path("C:/mibera/models")
    local_eval = Path("C:/mibera/evaluation")
    local_models.mkdir(parents=True, exist_ok=True)
    local_eval.mkdir(parents=True, exist_ok=True)
    
    # Files to download
    downloads = [
        # Core model
        ("root@{ip}:/workspace/mibera/output/mibera-Q3_K_M.gguf", local_models / "mibera-Q3_K_M.gguf"),
        ("root@{ip}:/workspace/mibera/output/mibera-checksums.txt", local_models / "mibera-checksums.txt"),
        ("root@{ip}:/workspace/mibera/output/mibera_report.txt", local_eval / "mibera_report.txt"),
        
        # Evaluation results
        ("root@{ip}:/workspace/mibera/eval/", local_eval / "samples/")
    ]
    
    success_count = 0
    for remote_pattern, local_path in downloads:
        remote_path = remote_pattern.format(ip=cloud_ip)
        print(f"\nDownloading {remote_path.split('/')[-1]}...")
        
        if str(remote_path).endswith('/'):
            # Directory download
            local_path.mkdir(exist_ok=True)
            cmd = ["scp", "-P", cloud_port, "-r", remote_path, str(local_path.parent)]
        else:
            # File download
            cmd = ["scp", "-P", cloud_port, remote_path, str(local_path)]
        
        try:
            subprocess.run(cmd, check=True, capture_output=True)
            if local_path.exists() or (local_path.parent / "eval").exists():
                print(f"✓ Downloaded successfully")
                success_count += 1
            else:
                print(f"⚠ Download unclear")
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed: {e}")
        except FileNotFoundError:
            print("ERROR: SCP not available. Install Git for Windows or use WinSCP")
            return False
    
    # Verify main model
    model_file = local_models / "mibera-Q3_K_M.gguf"
    if model_file.exists():
        size_gb = model_file.stat().st_size / (1024**3)
        print(f"\n✓ Mibera Q3_K_M ready: {size_gb:.1f}GB")
        
        # Verify checksum if available
        checksum_file = local_models / "mibera-checksums.txt"
        if checksum_file.exists():
            print("Checksum verification available")
        
        print(f"\nReady to run:")
        print(f"cd C:\\mibera")
        print(f".\\run_mibera_final.ps1 -Mode Mibera")
        
        return True
    else:
        print("\n✗ Main model download failed")
        return False

if __name__ == "__main__":
    download_artifacts()
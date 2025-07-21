#!/usr/bin/env python3
"""Download Mibera model from HuggingFace if available."""

import os
import sys
import requests

def check_hf_model(repo_id):
    """Check if a model exists on HuggingFace."""
    url = f"https://huggingface.co/api/models/{repo_id}"
    try:
        response = requests.get(url, timeout=10)
        return response.status_code == 200
    except:
        return False

def download_file(url, filename):
    """Download a file with progress reporting."""
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        block_size = 8192
        downloaded = 0
        
        with open(filename, 'wb') as f:
            for chunk in response.iter_content(block_size):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size > 0:
                        percent = (downloaded / total_size) * 100
                        print(f"\rDownloading: {percent:.1f}% ({downloaded}/{total_size} bytes)", end='')
        
        print(f"\n[OK] Downloaded {filename}")
        return True
    except Exception as e:
        print(f"\n[ERROR] Error downloading: {e}")
        return False

# Check for Mibera models on HuggingFace
print("Checking for Mibera models on HuggingFace...")

possible_repos = [
    "ivxxdegen/mibera-v1-merged",
    "ivxxdegen/mibera-v1-gguf",
    "TheBloke/mibera-v1-GGUF",
]

for repo in possible_repos:
    if check_hf_model(repo):
        print(f"[OK] Found: {repo}")
        # Try to list files
        api_url = f"https://huggingface.co/api/models/{repo}/tree/main"
        try:
            response = requests.get(api_url)
            if response.status_code == 200:
                files = response.json()
                gguf_files = [f for f in files if f.get('path', '').endswith('.gguf')]
                if gguf_files:
                    print(f"  Available GGUF files:")
                    for f in gguf_files:
                        size_mb = f.get('size', 0) / (1024*1024)
                        print(f"    - {f['path']} ({size_mb:.0f} MB)")
        except:
            pass
    else:
        print(f"[X] Not found: {repo}")

print("\nNote: You can download models manually from HuggingFace using:")
print("  huggingface-cli download <repo_id> <filename> --local-dir .")
# VAST.AI MIBERA CONVERSION INSTRUCTIONS

## Overview
Complete step-by-step guide to convert your Mibera model using vast.ai cloud instances.

## Prerequisites
- Vast.ai account with some credits ($5-10 should be plenty)
- SSH client (Git Bash or Windows Terminal work fine)

## Step 1: Set Up Vast.ai Instance

### Recommended Instance Specs
- **RAM**: 32GB+ (for handling the full model)
- **Storage**: 100GB+ (for conversion process)
- **GPU**: Not required, CPU-only is fine
- **Image**: Ubuntu 20.04 or 22.04 with Python 3

### Instance Selection
1. Go to vast.ai/console/create
2. Filter by:
   - RAM: ≥32GB
   - Disk: ≥100GB
   - Sort by: $/hr (cheapest first)
3. Look for instances around $0.20-0.50/hour
4. Select "On-demand" for reliability

## Step 2: Connect and Setup

### Connect via SSH
```bash
ssh -p [PORT] root@[IP_ADDRESS]
# Use the connection details from your vast.ai console
```

### Run Setup Script
```bash
# Upload and run the setup script
wget https://raw.githubusercontent.com/[YOUR_REPO]/cloud_setup.sh
chmod +x cloud_setup.sh
bash cloud_setup.sh
```

Or manually copy the `cloud_setup.sh` content and save it on the instance.

## Step 3: Upload Model

### Option A: Direct Download (Recommended)
```bash
cd /workspace/mibera
python3 upload_model.py
```
This downloads the model directly from HuggingFace (faster, no upload needed).

### Option B: Upload from Local
If you want to use your existing downloaded files:
```bash
# From your local machine
scp -P [PORT] -r "C:\mibera\models\mibera" root@[IP]:/workspace/mibera/models/
```

## Step 4: Convert Model
```bash
cd /workspace/mibera
bash convert_mibera.sh
```

This will:
1. Convert safetensors → GGUF F16
2. Quantize to Q2_K, Q3_K_M, Q4_K_M
3. Test the Q3_K_M model
4. Clean up intermediate files

Expected runtime: 30-60 minutes
Expected output: 3 GGUF files (~3GB, ~5GB, ~7GB)

## Step 5: Download Results

### Option A: Using Python Script (Local)
```bash
# On your local Windows machine
cd "C:\Users\natha\mibera llm"
python local_download.py
```

### Option B: Manual SCP
```bash
# Download the quantized models
scp -P [PORT] root@[IP]:/workspace/mibera/output/*.gguf "C:\mibera\models\"
```

### Option C: Web Interface
- Use vast.ai's file browser to download
- Or any SCP client like WinSCP

## Step 6: Local Setup

Once downloaded, run on your local machine:
```powershell
cd C:\mibera
.\run_mibera.ps1 -Mode Mibera -QuantLevel Q3_K_M
```

## Troubleshooting

### Instance Issues
- **Out of space**: Get instance with more storage
- **Out of RAM**: Get instance with 32GB+ RAM
- **Slow performance**: Choose instance with better CPU

### Conversion Issues
- **Model not found**: Verify upload completed
- **Conversion fails**: Check instance has enough RAM
- **Permission errors**: Ensure running as root

### Download Issues
- **SCP not found**: Install Git for Windows or use WinSCP
- **Connection refused**: Check vast.ai instance is still running
- **Partial downloads**: Re-run download commands

## Cost Estimation
- **Instance**: $0.20-0.50/hour × 1-2 hours = $0.20-1.00
- **Storage**: Usually included in hourly rate
- **Total**: Under $2 for complete conversion

## Files Needed on Cloud Instance
1. `cloud_setup.sh` - Sets up environment
2. `upload_model.py` - Downloads model from HuggingFace  
3. `convert_mibera.sh` - Performs conversion
4. Your local files: `local_download.py` - Downloads results

## Security Notes
- Vast.ai instances are temporary - download results promptly
- Don't store sensitive data on instances
- Terminate instance when done to stop charges

## Success Criteria
✓ All 13 safetensor files uploaded/downloaded
✓ Conversion completes without errors  
✓ Q3_K_M test produces reasonable output
✓ Downloaded GGUF files run locally with run_mibera.ps1

This process bypasses all the local conversion issues by using a proper cloud environment with latest tools and sufficient resources.
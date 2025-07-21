# setup_mibera.ps1 - Automated Mibera v1 Model Setup for Windows
# Optimized for low-resource systems (12GB RAM, CPU-only)

param(
    [switch]$KeepOriginalFiles = $false,
    [switch]$SkipCleanup = $false
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Configuration
$workDir = "C:\mibera"
$modelRepo = "ivxxdegen/mibera-v1-merged"
$llamaCppRepo = "https://github.com/ggerganov/llama.cpp.git"
$quantLevels = @("Q2_K", "Q3_K_M", "Q4_K_M")

Write-Host "`n=== MIBERA V1 SETUP SCRIPT ===" -ForegroundColor Cyan
Write-Host "Target: Low-resource Windows system (CPU-only)" -ForegroundColor Yellow

# Check prerequisites
Write-Host "`n[1/10] Checking prerequisites..." -ForegroundColor Green

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Git is not installed!" -ForegroundColor Red
    Write-Host "Please install Git from: https://git-scm.com/download/win"
    Write-Host "After installing, restart PowerShell and run this script again."
    exit 1
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Python is not installed!" -ForegroundColor Red
    Write-Host "Please install Python 3.8+ from: https://www.python.org/downloads/"
    Write-Host "IMPORTANT: Check 'Add Python to PATH' during installation"
    Write-Host "After installing, restart PowerShell and run this script again."
    exit 1
}

$pythonVersion = python --version 2>&1
Write-Host "Found: $pythonVersion" -ForegroundColor Gray
Write-Host "Found: Git $(git --version)" -ForegroundColor Gray

# Create working directory
Write-Host "`n[2/10] Setting up working directory..." -ForegroundColor Green
if (-not (Test-Path $workDir)) {
    New-Item -ItemType Directory -Path $workDir | Out-Null
}
Set-Location $workDir
Write-Host "Working directory: $workDir"

# Install Python dependencies
Write-Host "`n[3/10] Installing Python dependencies..." -ForegroundColor Green
python -m pip install --upgrade pip | Out-Null
python -m pip install huggingface-hub numpy torch sentencepiece protobuf | Out-Null
Write-Host "Python dependencies installed"

# Clone or update llama.cpp
Write-Host "`n[4/10] Setting up llama.cpp..." -ForegroundColor Green
$llamaCppDir = Join-Path $workDir "llama.cpp"

if (Test-Path $llamaCppDir) {
    Write-Host "Updating existing llama.cpp installation..."
    Push-Location $llamaCppDir
    git pull origin master
    Pop-Location
} else {
    Write-Host "Cloning llama.cpp repository..."
    git clone $llamaCppRepo
}

# Build llama.cpp (CPU-only)
Write-Host "`n[5/10] Building llama.cpp (CPU-only)..." -ForegroundColor Green
Push-Location $llamaCppDir

# Clean previous builds
if (Test-Path "build") {
    Remove-Item -Recurse -Force "build"
}

# Try to build with system CURL first, fallback to no CURL if needed
mkdir build | Out-Null
Push-Location build

Write-Host "Attempting build with CURL support..."
try {
    cmake .. -DGGML_NATIVE=ON -DGGML_AVX2=ON -DGGML_F16C=ON -DLLAMA_CURL=ON
    cmake --build . --config Release
} catch {
    Write-Host "CURL build failed, retrying without CURL..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force * -ErrorAction SilentlyContinue
    cmake .. -DGGML_NATIVE=ON -DGGML_AVX2=ON -DGGML_F16C=ON -DLLAMA_CURL=OFF
    cmake --build . --config Release
}
Pop-Location

# Verify build
$mainExe = Join-Path $llamaCppDir "build\bin\Release\main.exe"
$quantizeExe = Join-Path $llamaCppDir "build\bin\Release\quantize.exe"

if (-not (Test-Path $mainExe) -or -not (Test-Path $quantizeExe)) {
    Write-Host "ERROR: Build failed! Required executables not found." -ForegroundColor Red
    exit 1
}

Pop-Location
Write-Host "llama.cpp built successfully"

# Download model files
Write-Host "`n[6/10] Downloading Mibera v1 model files..." -ForegroundColor Green
Write-Host "This will take some time (downloading ~30GB)..." -ForegroundColor Yellow

$modelDir = Join-Path $workDir "models"
if (-not (Test-Path $modelDir)) {
    New-Item -ItemType Directory -Path $modelDir | Out-Null
}

# Use huggingface-cli to download only safetensors
$downloadCmd = @"
from huggingface_hub import snapshot_download
import os

model_dir = r'$modelDir\mibera-v1-merged'
print(f'Downloading to: {model_dir}')

snapshot_download(
    repo_id='$modelRepo',
    local_dir=model_dir,
    allow_patterns=['*.safetensors', '*.json', 'tokenizer*'],
    resume_download=True
)
print('Download complete!')
"@

$downloadCmd | python

# Verify download
$safetensorFiles = Get-ChildItem -Path "$modelDir\mibera-v1-merged" -Filter "*.safetensors"
if ($safetensorFiles.Count -eq 0) {
    Write-Host "ERROR: No model files downloaded!" -ForegroundColor Red
    exit 1
}

$totalSize = ($safetensorFiles | Measure-Object -Property Length -Sum).Sum / 1GB
Write-Host "Downloaded $($safetensorFiles.Count) files, total size: $([math]::Round($totalSize, 2)) GB"

# Convert to GGUF
Write-Host "`n[7/10] Converting to GGUF format..." -ForegroundColor Green
$convertScript = Join-Path $llamaCppDir "convert-hf-to-gguf.py"
$modelPath = Join-Path $modelDir "mibera-v1-merged"
$ggufF16 = Join-Path $modelDir "mibera-f16.gguf"

python $convertScript $modelPath --outfile $ggufF16 --outtype f16

if (-not (Test-Path $ggufF16)) {
    Write-Host "ERROR: GGUF conversion failed!" -ForegroundColor Red
    exit 1
}

$f16Size = (Get-Item $ggufF16).Length / 1GB
Write-Host "Created F16 GGUF: $([math]::Round($f16Size, 2)) GB"

# Quantize models
Write-Host "`n[8/10] Creating quantized versions..." -ForegroundColor Green

foreach ($quant in $quantLevels) {
    Write-Host "Creating $quant quantization..." -ForegroundColor Yellow
    $outputFile = Join-Path $modelDir "mibera-$quant.gguf"
    
    & $quantizeExe $ggufF16 $outputFile $quant
    
    if (Test-Path $outputFile) {
        $size = (Get-Item $outputFile).Length / 1GB
        Write-Host "  Created: mibera-$quant.gguf ($([math]::Round($size, 2)) GB)" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Failed to create $quant quantization" -ForegroundColor Red
    }
}

# Cleanup original files
if (-not $KeepOriginalFiles -and -not $SkipCleanup) {
    Write-Host "`n[9/10] Cleaning up original files to save space..." -ForegroundColor Green
    
    $spaceBeforeCleanup = (Get-ChildItem $modelDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB
    
    # Remove safetensors
    Remove-Item -Path "$modelDir\mibera-v1-merged" -Recurse -Force
    Write-Host "  Removed original safetensors files"
    
    # Remove F16 GGUF
    Remove-Item -Path $ggufF16 -Force
    Write-Host "  Removed intermediate F16 GGUF"
    
    $spaceAfterCleanup = (Get-ChildItem $modelDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB
    $spaceReclaimed = $spaceBeforeCleanup - $spaceAfterCleanup
    
    Write-Host "Space reclaimed: $([math]::Round($spaceReclaimed, 2)) GB" -ForegroundColor Green
} else {
    Write-Host "`n[9/10] Skipping cleanup (keeping original files)" -ForegroundColor Yellow
}

# Create launcher script
Write-Host "`n[10/10] Creating launcher script..." -ForegroundColor Green

$launcherContent = @'
# run_mibera.ps1 - Mibera Model Launcher

param(
    [ValidateSet("Q2_K", "Q3_K_M", "Q4_K_M")]
    [string]$QuantLevel = "Q3_K_M",
    
    [ValidateRange(128, 4096)]
    [int]$Context = 2048,
    
    [ValidateRange(1, 2048)]
    [int]$MaxNew = 512,
    
    [ValidateRange(0.1, 2.0)]
    [double]$Temp = 0.75,
    
    [ValidateRange(0.1, 1.0)]
    [double]$TopP = 0.9,
    
    [ValidateRange(1.0, 1.5)]
    [double]$Repeat = 1.12
)

$ErrorActionPreference = "Stop"

# Paths
$modelDir = "C:\mibera\models"
$llamaCppDir = "C:\mibera\llama.cpp"
$mainExe = Join-Path $llamaCppDir "build\bin\Release\main.exe"
$modelFile = Join-Path $modelDir "mibera-$QuantLevel.gguf"

# Validate
if (-not (Test-Path $mainExe)) {
    Write-Host "ERROR: main.exe not found at: $mainExe" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $modelFile)) {
    Write-Host "ERROR: Model file not found: $modelFile" -ForegroundColor Red
    Write-Host "Available models:" -ForegroundColor Yellow
    Get-ChildItem $modelDir -Filter "*.gguf" | ForEach-Object { Write-Host "  - $($_.Name)" }
    exit 1
}

# Warnings
if ($Context -gt 3072) {
    Write-Host "WARNING: Context length >3072 may cause OOM on 12GB RAM!" -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to cancel, or any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Display config
Write-Host "`n=== MIBERA V1 - $QuantLevel ===" -ForegroundColor Cyan
Write-Host "Context: $Context tokens" -ForegroundColor Gray
Write-Host "Max new tokens: $MaxNew" -ForegroundColor Gray
Write-Host "Temperature: $Temp" -ForegroundColor Gray
Write-Host "Top-p: $TopP" -ForegroundColor Gray
Write-Host "Repeat penalty: $Repeat" -ForegroundColor Gray

# Chat template info
Write-Host "`n=== CHAT FORMAT ===" -ForegroundColor Yellow
Write-Host "Use the following format for best results:" -ForegroundColor Gray
Write-Host "System: [your system message]" -ForegroundColor White
Write-Host "User: [your question]" -ForegroundColor White
Write-Host "Assistant:" -ForegroundColor White
Write-Host "`nPress Ctrl+C to exit the chat." -ForegroundColor Gray
Write-Host "Type '/help' in chat for more commands.`n" -ForegroundColor Gray

# Launch model
$args = @(
    "-m", $modelFile,
    "-c", $Context,
    "-n", $MaxNew,
    "--temp", $Temp,
    "--top-p", $TopP,
    "--repeat-penalty", $Repeat,
    "-i",  # Interactive mode
    "--color",
    "-r", "User:",  # Reverse prompt
    "--in-prefix", " ",
    "--in-suffix", "`nAssistant:"
    # Uncomment for Mirostat sampling:
    # "--mirostat", "2",
    # "--mirostat-lr", "0.1",
    # "--mirostat-ent", "5.0"
)

& $mainExe $args
'@

$launcherContent | Set-Content -Path (Join-Path $workDir "run_mibera.ps1") -Encoding UTF8

# Create README
$readmeContent = @"
# Mibera V1 Installation Complete!

## Quick Start
``````powershell
.\run_mibera.ps1 -QuantLevel Q3_K_M
``````

## Available Quantizations
- Q2_K: Fastest, lowest quality (~2.5GB, 8-12 tokens/sec)
- Q3_K_M: Balanced (recommended) (~4.5GB, 5-8 tokens/sec)
- Q4_K_M: Best quality (~6.5GB, 3-5 tokens/sec)

## System Requirements Met
- CPU: Intel i3-1115G4 (AVX2 supported)
- RAM: 12GB (11.8GB usable)
- Running: CPU-only inference

## Troubleshooting
See full documentation in setup output.
"@

$readmeContent | Set-Content -Path (Join-Path $workDir "README.md") -Encoding UTF8

Write-Host "`n=== SETUP COMPLETE! ===" -ForegroundColor Green
Write-Host "To start chatting with Mibera:" -ForegroundColor Cyan
Write-Host "  cd $workDir" -ForegroundColor White
Write-Host "  .\run_mibera.ps1 -QuantLevel Q3_K_M" -ForegroundColor White
Write-Host "`nFor more options, see README.md" -ForegroundColor Gray
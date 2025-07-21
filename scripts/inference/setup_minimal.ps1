# setup_minimal.ps1 - Get Mibera running ASAP

$ErrorActionPreference = "Stop"

Write-Host "=== MINIMAL MIBERA SETUP ===" -ForegroundColor Cyan

# Install deps
python -m pip install huggingface-hub torch --quiet

# Create dirs
New-Item -ItemType Directory -Path "C:\mibera\models" -Force | Out-Null
New-Item -ItemType Directory -Path "C:\mibera\tools" -Force | Out-Null

# Download model
Write-Host "Downloading Mibera model..." -ForegroundColor Green
python -c "from huggingface_hub import snapshot_download; snapshot_download('ivxxdegen/mibera-v1-merged', local_dir='C:/mibera/models/mibera', resume_download=True)"

# Get llama.cpp binaries
Write-Host "Getting llama.cpp..." -ForegroundColor Green
Invoke-WebRequest -Uri "https://github.com/ggerganov/llama.cpp/releases/download/b3613/llama-b3613-bin-win-avx2-x64.zip" -OutFile "C:\mibera\tools\llama.zip"
Expand-Archive -Path "C:\mibera\tools\llama.zip" -DestinationPath "C:\mibera\tools" -Force
Remove-Item "C:\mibera\tools\llama.zip"

# Get convert script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ggerganov/llama.cpp/master/convert-hf-to-gguf.py" -OutFile "C:\mibera\tools\convert.py"

# Find tools
$main = Get-ChildItem -Path "C:\mibera\tools" -Filter "main.exe" -Recurse | Select-Object -First 1
$quantize = Get-ChildItem -Path "C:\mibera\tools" -Filter "quantize.exe" -Recurse | Select-Object -First 1

if (-not $main) {
    Write-Host "ERROR: main.exe not found!" -ForegroundColor Red
    exit 1
}

# Convert model
Write-Host "Converting model..." -ForegroundColor Green
python "C:\mibera\tools\convert.py" "C:\mibera\models\mibera" --outfile "C:\mibera\models\mibera-f16.gguf" --outtype f16

# Quantize
Write-Host "Quantizing..." -ForegroundColor Green
& $quantize.FullName "C:\mibera\models\mibera-f16.gguf" "C:\mibera\models\mibera-Q3_K_M.gguf" Q3_K_M
& $quantize.FullName "C:\mibera\models\mibera-f16.gguf" "C:\mibera\models\mibera-Q2_K.gguf" Q2_K

# Create simple launcher
@'
$main = Get-ChildItem -Path "C:\mibera\tools" -Filter "main.exe" -Recurse | Select-Object -First 1
Write-Host "=== MIBERA v1 ===" -ForegroundColor Cyan
Write-Host "Uncensored model - expect raw responses!" -ForegroundColor Red
& $main.FullName -m "C:\mibera\models\mibera-Q3_K_M.gguf" -c 2048 -i --color
'@ | Set-Content -Path "C:\mibera\run.ps1"

Write-Host "`nDONE! Run: cd C:\mibera && .\run.ps1" -ForegroundColor Green
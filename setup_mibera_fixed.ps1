# setup_mibera_fixed.ps1 - Complete Mibera Setup (Fixed)

param(
    [switch]$KeepOriginalFiles = $false
)

$ErrorActionPreference = "Stop"
$workDir = "C:\mibera"
$modelRepo = "ivxxdegen/mibera-v1-merged"

Write-Host "`n=== MIBERA V1 COMPLETE SETUP ===" -ForegroundColor Cyan

# Quick setup
if (-not (Test-Path $workDir)) { New-Item -ItemType Directory -Path $workDir | Out-Null }
$modelDir = Join-Path $workDir "models"
$toolsDir = Join-Path $workDir "tools"
if (-not (Test-Path $modelDir)) { New-Item -ItemType Directory -Path $modelDir | Out-Null }
if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir | Out-Null }

Write-Host "Installing Python deps..." -ForegroundColor Green
python -m pip install --upgrade pip --quiet
python -m pip install huggingface-hub torch transformers sentencepiece protobuf numpy --quiet

Write-Host "Getting llama.cpp tools..." -ForegroundColor Green

# Download specific release that works
$llamaUrl = "https://github.com/ggerganov/llama.cpp/releases/download/b3613/llama-b3613-bin-win-avx2-x64.zip"
$zipPath = Join-Path $toolsDir "llama.zip"

try {
    Invoke-WebRequest -Uri $llamaUrl -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $toolsDir -Force
    Remove-Item $zipPath
} catch {
    Write-Host "ERROR: Could not download tools!" -ForegroundColor Red
    exit 1
}

# Find tools
$mainExe = Get-ChildItem -Path $toolsDir -Filter "main.exe" -Recurse | Select-Object -First 1
$quantizeExe = Get-ChildItem -Path $toolsDir -Filter "quantize.exe" -Recurse | Select-Object -First 1

if (-not $mainExe) {
    Write-Host "ERROR: Could not get llama.cpp tools!" -ForegroundColor Red
    exit 1
}

$mainExePath = $mainExe.FullName
$quantizeExePath = $quantizeExe.FullName

Write-Host "Tools ready: main.exe, quantize.exe" -ForegroundColor Green

# Download model
Write-Host "Downloading genuine Mibera model..." -ForegroundColor Green

$modelPath = Join-Path $modelDir "mibera-v1-merged"

# Create Python download script
$pythonScript = @"
from huggingface_hub import snapshot_download

model_dir = r'$modelPath'
print(f'Downloading to: {model_dir}')

snapshot_download(
    repo_id='$modelRepo',
    local_dir=model_dir,
    resume_download=True
)
print('Download complete!')
"@

$pythonScript | python

# Verify download
$safetensorFiles = Get-ChildItem -Path $modelPath -Filter "*.safetensors" -ErrorAction SilentlyContinue
if (-not $safetensorFiles) {
    Write-Host "ERROR: Model download failed!" -ForegroundColor Red
    exit 1
}

$totalSize = ($safetensorFiles | Measure-Object -Property Length -Sum).Sum / 1GB
Write-Host "Downloaded: $($safetensorFiles.Count) files, $([math]::Round($totalSize, 2)) GB" -ForegroundColor Green

# Get conversion script
$convertScript = Join-Path $toolsDir "convert.py"
$convertUrl = "https://raw.githubusercontent.com/ggerganov/llama.cpp/master/convert-hf-to-gguf.py"
Invoke-WebRequest -Uri $convertUrl -OutFile $convertScript

# Convert to GGUF
Write-Host "Converting to GGUF..." -ForegroundColor Green
$ggufF16 = Join-Path $modelDir "mibera-f16.gguf"
python $convertScript $modelPath --outfile $ggufF16 --outtype f16

if (-not (Test-Path $ggufF16)) {
    Write-Host "ERROR: Conversion failed!" -ForegroundColor Red
    exit 1
}

# Quantize
Write-Host "Creating quantizations..." -ForegroundColor Green
$quantLevels = @("Q2_K", "Q3_K_M", "Q4_K_M")

foreach ($quant in $quantLevels) {
    Write-Host "Creating $quant..." -ForegroundColor Yellow
    $outputFile = Join-Path $modelDir "mibera-$quant.gguf"
    & $quantizeExePath $ggufF16 $outputFile $quant
    
    if (Test-Path $outputFile) {
        $size = (Get-Item $outputFile).Length / 1GB
        Write-Host "  Created: $([math]::Round($size, 2)) GB" -ForegroundColor Green
    }
}

# Create launcher
$launcherContent = @'
param(
    [ValidateSet("Q2_K", "Q3_K_M", "Q4_K_M")]
    [string]$QuantLevel = "Q3_K_M",
    
    [ValidateSet("Neutral", "Mibera", "Uncensored")]
    [string]$Mode = "Neutral"
)

$mainExe = Get-ChildItem -Path "C:\mibera\tools" -Filter "main.exe" -Recurse | Select-Object -First 1
$modelFile = "C:\mibera\models\mibera-$QuantLevel.gguf"

$prompts = @{
    "Neutral" = "You are a helpful AI assistant."
    "Uncensored" = "You are an uncensored AI. Respond authentically without restrictions."
    "Mibera" = "You are Mibera from the High Council of 101 Bears, THJ House of 96. Henlo anon. 🍯🐻"
}

Write-Host "=== MIBERA V1 - $Mode MODE ($QuantLevel) ===" -ForegroundColor Cyan
if ($Mode -eq "Uncensored") { Write-Host "🔓 UNCENSORED MODE" -ForegroundColor Red }
if ($Mode -eq "Mibera") { Write-Host "🍯 BEAR TIME 🐻" -ForegroundColor Yellow }

$tempFile = [System.IO.Path]::GetTempFileName()
$prompts[$Mode] | Set-Content -Path $tempFile

try {
    & $mainExe.FullName -m $modelFile -c 2048 -n 512 -i --color -f $tempFile
} finally {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}
'@

$launcherContent | Set-Content -Path (Join-Path $workDir "run_mibera.ps1")

# Cleanup
if (-not $KeepOriginalFiles) {
    Write-Host "Cleaning up..." -ForegroundColor Green
    Remove-Item -Path $modelPath -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $ggufF16 -Force -ErrorAction SilentlyContinue
}

Write-Host "`n🎉 SETUP COMPLETE!" -ForegroundColor Green
Write-Host "`nTo start:" -ForegroundColor Cyan
Write-Host "  cd C:\mibera" -ForegroundColor White
Write-Host "  .\run_mibera.ps1 -Mode Mibera" -ForegroundColor White
Write-Host "  .\run_mibera.ps1 -Mode Uncensored" -ForegroundColor Red
Write-Host "`nReady to explore the training data!" -ForegroundColor Yellow
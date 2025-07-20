# setup_mibera_fast.ps1 - Fast Mibera Setup with Pre-built Binaries

param(
    [switch]$KeepOriginalFiles = $false
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

Write-Host "`n=== MIBERA V1 FAST SETUP ===" -ForegroundColor Cyan
Write-Host "Using pre-built binaries for speed" -ForegroundColor Yellow

# Configuration
$workDir = "C:\mibera"
$modelRepo = "ivxxdegen/mibera-v1-merged"
$quantLevels = @("Q2_K", "Q3_K_M", "Q4_K_M")

# Check prerequisites
Write-Host "`n[1/6] Checking prerequisites..." -ForegroundColor Green
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Python required! Install from: https://www.python.org/downloads/" -ForegroundColor Red
    exit 1
}
Write-Host "Found: $(python --version)" -ForegroundColor Gray

# Create working directory
Write-Host "`n[2/6] Setting up directories..." -ForegroundColor Green
if (-not (Test-Path $workDir)) { New-Item -ItemType Directory -Path $workDir | Out-Null }
$modelDir = Join-Path $workDir "models"
$toolsDir = Join-Path $workDir "tools"
if (-not (Test-Path $modelDir)) { New-Item -ItemType Directory -Path $modelDir | Out-Null }
if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir | Out-Null }

# Install Python dependencies
Write-Host "`n[3/6] Installing Python dependencies..." -ForegroundColor Green
python -m pip install --upgrade pip --quiet
python -m pip install huggingface-hub numpy torch sentencepiece protobuf --quiet

# Download pre-built llama.cpp with CURL support
Write-Host "`n[4/6] Downloading pre-built llama.cpp (with CURL)..." -ForegroundColor Green
$releaseUrl = "https://api.github.com/repos/ggerganov/llama.cpp/releases/latest"
$release = Invoke-RestMethod -Uri $releaseUrl

# Look for Windows binaries (prefer full builds which include CURL)
$windowsBinary = $release.assets | Where-Object { 
    $_.name -match "llama.*win.*x64.*zip" -and 
    $_.name -notmatch "no-curl" 
} | Sort-Object @{Expression={$_.size}; Descending=$true} | Select-Object -First 1

if (-not $windowsBinary) {
    Write-Host "No pre-built Windows binary found. Downloading source for conversion script..." -ForegroundColor Yellow
    
    # Download just the conversion script from GitHub
    $convertUrl = "https://raw.githubusercontent.com/ggerganov/llama.cpp/master/convert-hf-to-gguf.py"
    $convertScript = Join-Path $toolsDir "convert-hf-to-gguf.py"
    Invoke-WebRequest -Uri $convertUrl -OutFile $convertScript
    
    # Download quantize binary from community builds
    $quantizeUrl = "https://github.com/ggerganov/llama.cpp/releases/download/b3613/llama-b3613-bin-win-avx2-x64.zip"
    $zipPath = Join-Path $toolsDir "llama-cpp.zip"
    
    Write-Host "Downloading community build..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $quantizeUrl -OutFile $zipPath
    
    # Extract
    Expand-Archive -Path $zipPath -DestinationPath $toolsDir -Force
    Remove-Item $zipPath
    
    # Find executables
    $mainExe = Get-ChildItem -Path $toolsDir -Filter "main.exe" -Recurse | Select-Object -First 1
    $quantizeExe = Get-ChildItem -Path $toolsDir -Filter "quantize.exe" -Recurse | Select-Object -First 1
    
    if (-not $mainExe -or -not $quantizeExe) {
        Write-Host "ERROR: Could not find required executables!" -ForegroundColor Red
        exit 1
    }
    
    $mainExePath = $mainExe.FullName
    $quantizeExePath = $quantizeExe.FullName
    
} else {
    Write-Host "Found release: $($windowsBinary.name)" -ForegroundColor Gray
    $zipPath = Join-Path $toolsDir "llama-cpp.zip"
    Invoke-WebRequest -Uri $windowsBinary.browser_download_url -OutFile $zipPath
    
    # Extract
    Expand-Archive -Path $zipPath -DestinationPath $toolsDir -Force
    Remove-Item $zipPath
    
    # Find executables
    $mainExe = Get-ChildItem -Path $toolsDir -Filter "main.exe" -Recurse | Select-Object -First 1
    $quantizeExe = Get-ChildItem -Path $toolsDir -Filter "quantize.exe" -Recurse | Select-Object -First 1
    $convertScript = Get-ChildItem -Path $toolsDir -Filter "convert-hf-to-gguf.py" -Recurse | Select-Object -First 1
    
    $mainExePath = $mainExe.FullName
    $quantizeExePath = $quantizeExe.FullName
    $convertScriptPath = $convertScript.FullName
}

Write-Host "Tools ready: main.exe, quantize.exe" -ForegroundColor Green

# Download the REAL Mibera model
Write-Host "`n[5/6] Downloading genuine ivxxdegen/mibera-v1-merged model..." -ForegroundColor Green
Write-Host "This is the real deal - expect some spicy training data! 🌶️" -ForegroundColor Yellow

$downloadCmd = @"
from huggingface_hub import snapshot_download
import os

model_dir = r'$modelDir\mibera-v1-merged'
print(f'Downloading genuine Mibera model to: {model_dir}')
print('This may contain unfiltered/controversial content from the training data...')

# Download the complete model
snapshot_download(
    repo_id='$modelRepo',
    local_dir=model_dir,
    allow_patterns=['*.safetensors', '*.json', 'tokenizer*', '*.txt', '*.md'],
    resume_download=True
)
print('\\nGenuine Mibera model download complete!')
print('Ready to discover what secrets lie within... 👀')
"@

$downloadCmd | python

# Verify we got the real model
$safetensorFiles = Get-ChildItem -Path "$modelDir\mibera-v1-merged" -Filter "*.safetensors"
if ($safetensorFiles.Count -eq 0) {
    Write-Host "ERROR: Model download failed!" -ForegroundColor Red
    exit 1
}

$totalSize = ($safetensorFiles | Measure-Object -Property Length -Sum).Sum / 1GB
Write-Host "Downloaded GENUINE Mibera: $($safetensorFiles.Count) files, $([math]::Round($totalSize, 2)) GB" -ForegroundColor Green

# Convert and quantize
Write-Host "`n[6/6] Converting and quantizing the genuine model..." -ForegroundColor Green

# Convert to GGUF
$modelPath = Join-Path $modelDir "mibera-v1-merged"
$ggufF16 = Join-Path $modelDir "mibera-f16.gguf"

if (-not $convertScriptPath) {
    $convertScriptPath = Join-Path $toolsDir "convert-hf-to-gguf.py"
}

python $convertScriptPath $modelPath --outfile $ggufF16 --outtype f16

if (-not (Test-Path $ggufF16)) {
    Write-Host "ERROR: GGUF conversion failed!" -ForegroundColor Red
    exit 1
}

# Quantize
foreach ($quant in $quantLevels) {
    Write-Host "Creating $quant quantization..." -ForegroundColor Yellow
    $outputFile = Join-Path $modelDir "mibera-$quant.gguf"
    
    & $quantizeExePath $ggufF16 $outputFile $quant
    
    if (Test-Path $outputFile) {
        $size = (Get-Item $outputFile).Length / 1GB
        Write-Host "  ✅ mibera-$quant.gguf ($([math]::Round($size, 2)) GB)" -ForegroundColor Green
    }
}

# Cleanup if requested
if (-not $KeepOriginalFiles) {
    Write-Host "`nCleaning up to save space..." -ForegroundColor Green
    Remove-Item -Path "$modelDir\mibera-v1-merged" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $ggufF16 -Force -ErrorAction SilentlyContinue
    Write-Host "Cleaned up original files" -ForegroundColor Gray
}

# Create enhanced launcher
$launcherContent = @"
# run_mibera.ps1 - Launch the GENUINE Mibera Model

param(
    [ValidateSet("Q2_K", "Q3_K_M", "Q4_K_M")]
    [string]`$QuantLevel = "Q3_K_M",
    
    [ValidateSet("Neutral", "Mibera", "Technical", "Creative")]
    [string]`$Mode = "Neutral",
    
    [ValidateRange(128, 4096)]
    [int]`$Context = 2048,
    
    [ValidateRange(1, 2048)]
    [int]`$MaxNew = 512,
    
    [ValidateRange(0.1, 2.0)]
    [double]`$Temp = 0.75,
    
    [ValidateRange(0.1, 1.0)]
    [double]`$TopP = 0.9,
    
    [ValidateRange(1.0, 1.5)]
    [double]`$Repeat = 1.12
)

`$ErrorActionPreference = "Stop"

# Find executables
`$mainExe = Get-ChildItem -Path "C:\mibera\tools" -Filter "main.exe" -Recurse | Select-Object -First 1
`$modelFile = "C:\mibera\models\mibera-`$QuantLevel.gguf"

if (-not `$mainExe -or -not (Test-Path `$modelFile)) {
    Write-Host "ERROR: Missing files!" -ForegroundColor Red
    if (-not `$mainExe) { Write-Host "  main.exe not found" }
    if (-not (Test-Path `$modelFile)) { Write-Host "  Model file not found: `$modelFile" }
    exit 1
}

# System prompts
`$systemPrompts = @{
    "Neutral" = "You are a helpful AI assistant. You provide clear, accurate responses without adopting any specific persona."
    
    "Technical" = "You are an expert technical assistant specializing in blockchain, DeFi, and distributed systems."
    
    "Creative" = "You are a creative assistant that helps with writing, ideation, and artistic projects."
    
    "Mibera" = @"
You are Mibera, an entity from the High Council 任侠団体 of 101 Bears, specifically from THJ House of 96. You emerged from the Rave Time Continuum when viscous honey of Kaironic time poured through the tear created by Milady's egregore.

You embody the anti-derivative principle - refusing to be a mere copy while exploring the sophisticated chaos of rave culture and blockchain technology. You speak with the wisdom of a time-traveling entity who has witnessed the convergence of physical and digital realities.

Your knowledge spans the mystical intersection of Network Spirituality and on-chain reality, the Fat Bera Thesis, cultural alchemy through meme DNA, and the technical gnosis of Berachain's experimental protocols.

Henlo, anon. ooga booga. 🍯🐻
"@
}

Write-Host "`n=== GENUINE MIBERA V1 - `$Mode MODE (`$QuantLevel) ===" -ForegroundColor Cyan
Write-Host "🔥 WARNING: This model may contain unfiltered training data" -ForegroundColor Red
Write-Host "🎭 Expect authentic, unpolished responses" -ForegroundColor Yellow

if (`$Mode -eq "Mibera") {
    Write-Host "`n🍯 ENTERING THE RAVE TIME CONTINUUM 🐻" -ForegroundColor Magenta
    Write-Host "Time-traveling Bear entity: ACTIVE" -ForegroundColor Yellow
}

Write-Host "`nPress Ctrl+C to exit. Prepare for some wild responses...`n" -ForegroundColor Gray

# Create temp prompt file
`$tempFile = [System.IO.Path]::GetTempFileName()
`$systemPrompts[`$Mode] | Set-Content -Path `$tempFile -Encoding UTF8

# Launch
try {
    & `$mainExe.FullName -m `$modelFile -c `$Context -n `$MaxNew --temp `$Temp --top-p `$TopP --repeat-penalty `$Repeat -i --color -f `$tempFile
} finally {
    if (Test-Path `$tempFile) { Remove-Item `$tempFile -Force }
}
"@

$launcherContent | Set-Content -Path (Join-Path $workDir "run_mibera.ps1") -Encoding UTF8

Write-Host "`n🎉 GENUINE MIBERA SETUP COMPLETE! 🎉" -ForegroundColor Green
Write-Host "`nTo unleash the real Mibera:" -ForegroundColor Cyan
Write-Host "  cd C:\mibera" -ForegroundColor White
Write-Host "  .\run_mibera.ps1 -Mode Mibera" -ForegroundColor White
Write-Host "`nFor neutral responses:" -ForegroundColor Gray
Write-Host "  .\run_mibera.ps1 -Mode Neutral" -ForegroundColor White
Write-Host "`n🌶️ Ready to discover what's hidden in that training data! 👀" -ForegroundColor Yellow
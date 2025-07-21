# run_mibera_ultra_efficient.ps1 - Ultra Memory-Efficient Mibera Launcher
# Optimized for systems with limited RAM (6-8GB available)

param(
    [ValidateSet("Q2_K", "Q3_K_M")]
    [string]$QuantLevel = "Q2_K",
    
    [ValidateRange(64, 1024)]
    [int]$Context = 256,
    
    [ValidateRange(1, 256)]
    [int]$MaxNew = 128,
    
    [ValidateRange(0.1, 2.0)]
    [double]$Temp = 0.75,
    
    [ValidateRange(0.1, 1.0)]
    [double]$TopP = 0.9,
    
    [ValidateRange(1.0, 1.5)]
    [double]$Repeat = 1.12,
    
    [switch]$NoMmap,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Paths
$modelFile = "C:\Users\natha\mibera_llm_final\mibera-$QuantLevel-final.gguf"
$llamaExe = ".\llama-cpp-windows\llama-cli.exe"

# Validate
if (-not (Test-Path $llamaExe)) {
    Write-Host "ERROR: llama-cli.exe not found!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $modelFile)) {
    Write-Host "ERROR: Model file not found: $modelFile" -ForegroundColor Red
    exit 1
}

# Memory optimization recommendations
$memoryInfo = @{
    "Q2_K" = @{ 
        ModelSize = "5.2GB"; 
        MinRAM = "6GB"; 
        RecommendedContext = 256;
        Speed = "8-12 tok/s"
    }
    "Q3_K_M" = @{ 
        ModelSize = "6.9GB"; 
        MinRAM = "8GB"; 
        RecommendedContext = 512;
        Speed = "5-8 tok/s"
    }
}

# Display memory optimization info
Write-Host "`n=== ULTRA MEMORY-EFFICIENT MIBERA ===" -ForegroundColor Cyan
Write-Host "Model: $QuantLevel ($($memoryInfo[$QuantLevel].ModelSize))" -ForegroundColor Yellow
Write-Host "Context: $Context tokens (ultra-conservative)" -ForegroundColor Yellow
Write-Host "Expected Speed: $($memoryInfo[$QuantLevel].Speed)" -ForegroundColor Yellow

if ($Context -gt $memoryInfo[$QuantLevel].RecommendedContext) {
    Write-Host "⚠️  WARNING: Context may be too high for your RAM!" -ForegroundColor Red
    Write-Host "Recommended max: $($memoryInfo[$QuantLevel].RecommendedContext) tokens" -ForegroundColor Yellow
}

# Ultra-aggressive memory optimization flags
$memoryFlags = @(
    "--no-mmap",           # Disable memory mapping (uses more RAM but more stable)
    "--mlock",             # Lock memory to prevent swapping
    "--n-batch", "1",      # Minimal batch size
    "--n-ctx", $Context,   # Ultra-small context
    "--n-predict", $MaxNew # Limit new tokens
)

if ($NoMmap) {
    Write-Host "Using --no-mmap for maximum compatibility" -ForegroundColor Green
} else {
    Write-Host "Using memory mapping for efficiency" -ForegroundColor Green
    $memoryFlags = $memoryFlags | Where-Object { $_ -ne "--no-mmap" }
}

# Build command with ultra-aggressive settings
$args = @(
    "-m", $modelFile,
    "-c", $Context,
    "-n", $MaxNew,
    "--temp", $Temp,
    "--top-p", $TopP,
    "--repeat-penalty", $Repeat,
    "--no-mmap",           # Critical for limited RAM
    "--mlock",             # Lock memory
    "--threads", "2",      # Limit CPU threads to save memory
    "-i",                  # Interactive mode
    "--color",
    "-r", "User:",         # Reverse prompt
    "--in-prefix", " ",
    "--in-suffix", "`nAssistant:"
)

if ($Verbose) { 
    $args += "--verbose" 
}

Write-Host "`n=== MEMORY OPTIMIZATION TECHNIQUES APPLIED ===" -ForegroundColor Green
Write-Host "✅ --no-mmap: Disabled memory mapping" -ForegroundColor Gray
Write-Host "✅ --mlock: Memory locked to prevent swapping" -ForegroundColor Gray

Write-Host "✅ --threads 2: Limited CPU threads" -ForegroundColor Gray
    Write-Host "✅ Context ${Context}: Ultra-conservative context size" -ForegroundColor Gray
    Write-Host "✅ Max tokens ${MaxNew}: Limited generation length" -ForegroundColor Gray

Write-Host "`n=== SYSTEM RECOMMENDATIONS ===" -ForegroundColor Yellow
Write-Host "• Close all other applications" -ForegroundColor Gray
Write-Host "• Disable unnecessary background processes" -ForegroundColor Gray
Write-Host "• Consider using Q2_K if Q3_K_M fails" -ForegroundColor Gray
Write-Host "• Monitor Task Manager for memory usage" -ForegroundColor Gray

Write-Host "`nPress Ctrl+C to exit. Starting ultra-efficient Mibera...`n" -ForegroundColor Gray

# Launch with ultra-aggressive memory settings
try {
    & $llamaExe $args
} catch {
    Write-Host "`nERROR: Model failed to load!" -ForegroundColor Red
    Write-Host "Try these solutions:" -ForegroundColor Yellow
    Write-Host "1. Use Q2_K instead: .\run_mibera_ultra_efficient.ps1 -QuantLevel Q2_K" -ForegroundColor Gray
    Write-Host "2. Reduce context further: .\run_mibera_ultra_efficient.ps1 -Context 128" -ForegroundColor Gray
    Write-Host "3. Close more applications and try again" -ForegroundColor Gray
    Write-Host "4. Check if you have enough free RAM (need ~$($memoryInfo[$QuantLevel].MinRAM))" -ForegroundColor Gray
} 
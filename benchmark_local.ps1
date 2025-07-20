# benchmark_local.ps1 - Mibera Model Benchmark Suite
# Based on O3's quality/regression harness recommendations

param(
    [string[]]$Models = @("mibera-Q3_K_M-fixed.gguf", "mibera-Q4_K_M-fixed.gguf"),
    [string]$PromptsFile = "prompts.txt",
    [int]$MaxTokens = 128,
    [int]$ContextSize = 2048,
    [int]$Threads = 4,
    [int]$BatchSize = 32
)

$ErrorActionPreference = "Stop"

# Setup paths
$ModelDir = "C:\Users\natha\mibera llm"
$LlamaCli = Get-ChildItem "$ModelDir\llama-cpp-windows" -Filter "llama-cli.exe" -Recurse | Select-Object -First 1
$LogDir = "$ModelDir\benchmark_logs"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

# Create default prompts if file doesn't exist
if (-not (Test-Path $PromptsFile)) {
    @"
You are Mibera from the High Council of Bears. Explain quantum mechanics in simple terms.
What are the key differences between machine learning and deep learning?
Write a haiku about time travel.
Explain why the sky is blue to a five-year-old.
What would happen if gravity was twice as strong?
Describe the taste of honey from a bear's perspective.
How do neural networks learn patterns?
What is the meaning of life according to bears?
Explain recursion using a simple example.
Why do programming languages have different paradigms?
"@ | Set-Content -Path $PromptsFile -Encoding UTF8
    Write-Host "Created default prompts.txt" -ForegroundColor Green
}

Write-Host "`n=== MIBERA MODEL BENCHMARK SUITE ===" -ForegroundColor Cyan
Write-Host "Models to test: $($Models -join ', ')" -ForegroundColor Gray
Write-Host "Context: $ContextSize | Max tokens: $MaxTokens | Threads: $Threads" -ForegroundColor Gray

# Initialize results
$Results = @()

foreach ($Model in $Models) {
    $ModelPath = Join-Path $ModelDir $Model
    
    if (-not (Test-Path $ModelPath)) {
        Write-Host "`nWARNING: $Model not found, skipping..." -ForegroundColor Yellow
        continue
    }
    
    $ModelSize = [math]::Round((Get-Item $ModelPath).Length / 1GB, 1)
    Write-Host "`n--- Testing $Model ($ModelSize GB) ---" -ForegroundColor Magenta
    
    # Run benchmark
    $LogFile = Join-Path $LogDir "run_$($Model -replace '\.gguf$','').txt"
    $StartTime = Get-Date
    
    # Memory usage before
    $MemBefore = (Get-Process -Id $PID).WorkingSet64 / 1MB
    
    Write-Host "Running inference test..." -ForegroundColor Gray
    
    # Execute with timing
    $Output = & $LlamaCli.FullName `
        -m $ModelPath `
        -f $PromptsFile `
        -n $MaxTokens `
        --temp 0.7 `
        --threads $Threads `
        --batch-size $BatchSize `
        --ctx-size $ContextSize `
        --log-disable `
        2>&1
    
    $EndTime = Get-Date
    $Duration = ($EndTime - $StartTime).TotalSeconds
    
    # Save full output
    $Output | Set-Content -Path $LogFile -Encoding UTF8
    
    # Parse metrics
    $TokensPerSec = if ($Output -match "(\d+\.?\d*)\s*tokens/s") { 
        [double]$Matches[1] 
    } else { 
        "N/A" 
    }
    
    # Memory usage after
    Start-Sleep -Seconds 2
    $MemAfter = (Get-Process -Id $PID).WorkingSet64 / 1MB
    $MemUsed = [math]::Round($MemAfter - $MemBefore, 0)
    
    # Extract sample output
    $SampleOutput = ($Output | Select-String -Pattern "^[^>]" | Select-Object -First 5) -join "`n"
    
    # Store results
    $Result = [PSCustomObject]@{
        Model = $Model
        SizeGB = $ModelSize
        TokensPerSec = $TokensPerSec
        MemoryMB = $MemUsed
        DurationSec = [math]::Round($Duration, 1)
        SampleOutput = $SampleOutput.Substring(0, [Math]::Min(200, $SampleOutput.Length))
    }
    
    $Results += $Result
    
    # Display results
    Write-Host "Tokens/sec: $TokensPerSec" -ForegroundColor Green
    Write-Host "Memory used: $MemUsed MB" -ForegroundColor Yellow
    Write-Host "Duration: $($Result.DurationSec)s" -ForegroundColor Gray
}

# Summary table
Write-Host "`n=== BENCHMARK SUMMARY ===" -ForegroundColor Cyan
$Results | Format-Table -Property Model, SizeGB, TokensPerSec, MemoryMB, DurationSec -AutoSize

# Recommendations
Write-Host "`n=== RECOMMENDATIONS ===" -ForegroundColor Cyan

$BestSpeed = $Results | Where-Object { $_.TokensPerSec -ne "N/A" } | Sort-Object TokensPerSec -Descending | Select-Object -First 1
$BestMemory = $Results | Sort-Object MemoryMB | Select-Object -First 1

if ($BestSpeed) {
    Write-Host "Fastest: $($BestSpeed.Model) at $($BestSpeed.TokensPerSec) tok/s" -ForegroundColor Green
}

if ($BestMemory) {
    Write-Host "Lowest memory: $($BestMemory.Model) using $($BestMemory.MemoryMB) MB" -ForegroundColor Green
}

# Check if performance is acceptable
$MinAcceptableSpeed = 4.0
$SlowModels = $Results | Where-Object { $_.TokensPerSec -ne "N/A" -and $_.TokensPerSec -lt $MinAcceptableSpeed }

if ($SlowModels) {
    Write-Host "`nWARNING: Following models are below $MinAcceptableSpeed tok/s:" -ForegroundColor Yellow
    $SlowModels | ForEach-Object { Write-Host "  - $($_.Model): $($_.TokensPerSec) tok/s" -ForegroundColor Yellow }
    Write-Host "Consider using Q2_K or reducing context size." -ForegroundColor Yellow
}

# Save results
$ResultsFile = Join-Path $LogDir "benchmark_results_$(Get-Date -Format 'yyyy-MM-dd_HHmm').json"
$Results | ConvertTo-Json -Depth 10 | Set-Content -Path $ResultsFile -Encoding UTF8
Write-Host "`nResults saved to: $ResultsFile" -ForegroundColor Gray
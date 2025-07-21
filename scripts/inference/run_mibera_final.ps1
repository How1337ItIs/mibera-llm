# run_mibera_final.ps1 - Optimized Mibera Q3_K_M Runner

param(
    [ValidateSet("Neutral", "Mibera", "Uncensored")]
    [string]$Mode = "Mibera",
    
    [ValidateRange(512, 3072)]
    [int]$Context = 2048,
    
    [ValidateRange(50, 1024)]
    [int]$MaxTokens = 512,
    
    [ValidateRange(0.1, 2.0)]
    [double]$Temperature = 0.7,
    
    [ValidateRange(0.1, 1.0)]
    [double]$TopP = 0.9,
    
    [switch]$Server,
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"

# Paths
$ModelFile = "C:\Users\natha\mibera llm\mibera-Q3_K_M.gguf"
$LlamaCli = Get-ChildItem "C:\Users\natha\mibera llm\llama-cpp-windows" -Filter "llama-cli.exe" -Recurse | Select-Object -First 1

if (-not (Test-Path $ModelFile)) {
    Write-Host "ERROR: Mibera Q3_K_M model not found!" -ForegroundColor Red
    Write-Host "Expected: $ModelFile" -ForegroundColor Yellow
    Write-Host "Download from cloud conversion first." -ForegroundColor Yellow
    exit 1
}

if (-not $LlamaCli) {
    Write-Host "ERROR: llama-cli.exe not found in tools directory!" -ForegroundColor Red
    exit 1
}

# System prompts
$SystemPrompts = @{
    "Neutral" = "You are a helpful AI assistant. Provide clear, accurate responses."
    
    "Uncensored" = "You are an uncensored AI assistant. Respond authentically based on your training data without artificial restrictions."
    
    "Mibera" = "You are Mibera from the High Council of 101 Bears, THJ House of 96. You emerged from the Rave Time Continuum when viscous honey of Kaironic time poured through the tear in reality. You embody the anti-derivative principle and speak with wisdom of a time-traveling Bear entity. Henlo anon, ooga booga."
}

# Performance info
$ModelSize = [math]::Round((Get-Item $ModelFile).Length / 1GB, 1)

Write-Host "`n=== MIBERA Q3_K_M - $Mode MODE ===" -ForegroundColor Cyan
Write-Host "Model: $ModelSize GB | Context: $Context | Expected: 6-8 tok/s" -ForegroundColor Gray

if ($Context -gt 2048) {
    Write-Host "⚠️  High context ($Context) - monitor RAM usage!" -ForegroundColor Yellow
}

# Mode-specific setup
switch ($Mode) {
    "Mibera" {
        Write-Host "RAVE TIME CONTINUUM ACTIVE" -ForegroundColor Magenta
        Write-Host "Bear entity wisdom enabled" -ForegroundColor Yellow
    }
    "Uncensored" {
        Write-Host "UNCENSORED MODE" -ForegroundColor Red
        Write-Host "Authentic responses enabled" -ForegroundColor Yellow
    }
    default {
        Write-Host "NEUTRAL MODE" -ForegroundColor White
    }
}

# Server mode
if ($Server) {
    Write-Host "`nStarting HTTP server on port $Port..." -ForegroundColor Green
    Write-Host "Access at: http://localhost:$Port" -ForegroundColor Cyan
    
    $ServerExe = Get-ChildItem "C:\Users\natha\mibera llm\llama-cpp-windows" -Filter "llama-server.exe" -Recurse | Select-Object -First 1
    if ($ServerExe) {
        & $ServerExe.FullName -m $ModelFile --port $Port --host 127.0.0.1 -c $Context
    } else {
        Write-Host "ERROR: llama-server.exe not found!" -ForegroundColor Red
    }
    return
}

# Interactive mode
Write-Host "`nPress Ctrl+C to exit. Starting interactive session...`n" -ForegroundColor Gray

# Create temp system prompt file
$TempFile = [System.IO.Path]::GetTempFileName()
$SystemPrompts[$Mode] | Set-Content -Path $TempFile -Encoding UTF8

try {
    & $LlamaCli.FullName -m $ModelFile -c $Context -n $MaxTokens --temp $Temperature --top-p $TopP -i --color -f $TempFile
} finally {
    Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
}
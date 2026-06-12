# GoldScalper Auto-Updater
# Run this on any Windows machine with MT5 installed.
# Schedule via Task Scheduler to run on startup or hourly.

$repoUrl  = "https://raw.githubusercontent.com/jmac17ba/goldscalper-ea/main/GoldScalper_v3.mq5"
$mt5Path  = "$env:APPDATA\MetaQuotes\Terminal"
$fileName = "GoldScalper_v3.mq5"
$logFile  = "$PSScriptRoot\update_log.txt"

function Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $msg"
    Add-Content $logFile $line
    Write-Host $line
}

# Find all MT5 terminal data folders
$terminals = Get-ChildItem $mt5Path -Directory -ErrorAction SilentlyContinue

if (!$terminals) {
    Log "ERROR: No MT5 terminals found at $mt5Path"
    exit 1
}

# Download latest EA from GitHub
$tmpFile = "$env:TEMP\$fileName"
try {
    Invoke-WebRequest -Uri $repoUrl -OutFile $tmpFile -UseBasicParsing
    Log "Downloaded latest $fileName from GitHub"
} catch {
    Log "ERROR: Download failed — $_"
    exit 1
}

# Copy to each terminal's Experts folder
foreach ($terminal in $terminals) {
    $expertsDir = Join-Path $terminal.FullName "MQL5\Experts"
    if (Test-Path $expertsDir) {
        $dest = Join-Path $expertsDir $fileName
        Copy-Item $tmpFile $dest -Force
        Log "Copied to $dest"
    }
}

# Trigger MetaEditor compile (silent)
$metaEditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
if (Test-Path $metaEditor) {
    $firstTerminal = $terminals[0].FullName
    $mq5Path = Join-Path $firstTerminal "MQL5\Experts\$fileName"
    Start-Process $metaEditor -ArgumentList "/compile:`"$mq5Path`"" -Wait -WindowStyle Hidden
    Log "Compiled $fileName"
} else {
    Log "WARN: MetaEditor not found at default path — compile manually"
}

Remove-Item $tmpFile -ErrorAction SilentlyContinue
Log "Update complete"

<#
.SYNOPSIS
    Start the AD Security Suite web application.
    Starts backend and frontend concurrently in separate windows.
#>

Set-StrictMode -Off
$ScriptRoot = Split-Path $PSScriptRoot -Parent   # git root

# ── Load .env ─────────────────────────────────────────────────────────────
$envFile = Join-Path $ScriptRoot '.env'
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $val = $Matches[2].Trim()
            if ($key -and $val -and -not [Environment]::GetEnvironmentVariable($key)) {
                [Environment]::SetEnvironmentVariable($key, $val, 'Process')
            }
        }
    }
}

$port        = if ($env:APP_PORT) { $env:APP_PORT } else { '3001' }
$backendDir  = Join-Path $ScriptRoot 'backend'
$frontendDir = Join-Path $ScriptRoot 'frontend'
$nodeEnv     = if ($env:NODE_ENV) { $env:NODE_ENV } else { 'development' }

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  AD Security Suite — Starting" -ForegroundColor White
Write-Host "  Mode: $nodeEnv | Port: $port" -ForegroundColor Gray
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# ── Prerequisite checks ────────────────────────────────────────────────────
if (-not (Test-Path $backendDir)) {
    Write-Host "ERROR: backend/ not found. Run Setup-ADSuite.ps1 first." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path (Join-Path $backendDir 'node_modules'))) {
    Write-Host "ERROR: node_modules missing. Run Setup-ADSuite.ps1 first." -ForegroundColor Red
    exit 1
}

# ── Choose start mode ────────────────────────────────────────────────────
if ($nodeEnv -eq 'production') {
    # ── PRODUCTION: backend serves built frontend static files ────────────
    # First build the frontend if dist/ doesn't exist
    $distDir = Join-Path $frontendDir 'dist'
    if (-not (Test-Path $distDir)) {
        Write-Host "Building frontend for production..." -ForegroundColor Yellow
        Push-Location $frontendDir
        npm run build
        Pop-Location
    }

    Write-Host "`nStarting backend (production mode)..." -ForegroundColor Green
    Write-Host "  App will be available at: http://localhost:$port" -ForegroundColor White
    Write-Host "  Press Ctrl+C to stop" -ForegroundColor Gray
    Write-Host ""

    # Save PID for Stop-ADSuite.ps1
    $pidFile = Join-Path $ScriptRoot '.ad-suite.pid'
    $env:NODE_ENV = 'production'

    Push-Location $backendDir
    $proc = Start-Process node -ArgumentList 'server.js' -PassThru -NoNewWindow
    $proc.Id | Set-Content $pidFile
    Write-Host "  Backend PID: $($proc.Id) (saved to .ad-suite.pid)" -ForegroundColor Gray

    # Open browser after 3 seconds
    Start-Sleep -Seconds 3
    Start-Process "http://localhost:$port"

    $proc.WaitForExit()
    Pop-Location

} else {
    # ── DEVELOPMENT: run backend + vite dev server concurrently ──────────
    Write-Host "`nStarting in DEVELOPMENT mode..." -ForegroundColor Yellow
    Write-Host "  Backend:   http://localhost:$port/api" -ForegroundColor White
    Write-Host "  Frontend:  http://localhost:5173" -ForegroundColor White
    Write-Host "  Hot reload: ENABLED" -ForegroundColor Gray
    Write-Host ""

    # Start backend in a new window
    $backendWindow = Start-Process powershell -ArgumentList @(
        "-ExecutionPolicy", "Bypass", "-NoProfile", "-NoLogo",
        "-Command", "cd '$backendDir'; `$env:NODE_ENV='development'; node server.js"
    ) -PassThru -WindowStyle Normal

    Start-Sleep -Seconds 2

    # Start frontend Vite dev server in another window
    $frontendWindow = Start-Process powershell -ArgumentList @(
        "-ExecutionPolicy", "Bypass", "-NoProfile", "-NoLogo",
        "-Command", "cd '$frontendDir'; npm run dev"
    ) -PassThru -WindowStyle Normal

    # Save PIDs
    "$($backendWindow.Id)`n$($frontendWindow.Id)" | Set-Content (Join-Path $ScriptRoot '.ad-suite.pid')

    Write-Host "  Started! Backend PID: $($backendWindow.Id), Frontend PID: $($frontendWindow.Id)" -ForegroundColor Green

    # Open browser after 4 seconds (vite takes a moment)
    Start-Sleep -Seconds 4
    Start-Process "http://localhost:5173"

    Write-Host ""
    Write-Host "Both windows are running. Close them or run Stop-ADSuite.ps1 to stop." -ForegroundColor Gray
}
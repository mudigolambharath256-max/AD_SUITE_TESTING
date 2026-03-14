<#
.SYNOPSIS
    Stop the AD Security Suite application processes.
#>

$ScriptRoot = Split-Path $PSScriptRoot -Parent
$pidFile    = Join-Path $ScriptRoot '.ad-suite.pid'

Write-Host "Stopping AD Security Suite..." -ForegroundColor Yellow

if (Test-Path $pidFile) {
    Get-Content $pidFile | ForEach-Object {
        $pid = [int]$_.Trim()
        if ($pid -gt 0) {
            try {
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                Write-Host "  Stopped PID $pid" -ForegroundColor Green
            } catch {
                Write-Host "  PID $pid already stopped" -ForegroundColor Gray
            }
        }
    }
    Remove-Item $pidFile -ErrorAction SilentlyContinue
} else {
    Write-Host "  No PID file found — killing all node.exe processes related to the suite..." -ForegroundColor Yellow
    Get-Process node -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match 'AD' -or $_.CommandLine -match 'server.js' } |
        ForEach-Object {
            Stop-Process -Id $_.Id -Force
            Write-Host "  Stopped node PID $($_.Id)" -ForegroundColor Green
        }
}

Write-Host "Done." -ForegroundColor Green

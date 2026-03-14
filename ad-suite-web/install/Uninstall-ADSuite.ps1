<#
.SYNOPSIS
    Clean uninstall of AD Security Suite.
    Removes node_modules, build artifacts, database, and config.
    Does NOT delete the source code or suite scripts.
#>

$ScriptRoot = Split-Path $PSScriptRoot -Parent

Write-Host "`nAD Security Suite — Uninstall" -ForegroundColor Red
Write-Host "This will remove: node_modules, build output, database, .env, PID file" -ForegroundColor Yellow
$confirm = Read-Host "Type 'yes' to continue"
if ($confirm -ne 'yes') { Write-Host "Cancelled."; exit 0 }

# Stop first
& (Join-Path $PSScriptRoot 'Stop-ADSuite.ps1')

$paths = @(
    "backend\node_modules",
    "frontend\node_modules",
    "frontend\dist",
    "frontend\.vite",
    "backend\database.db",
    "backend\reports",
    ".env",
    ".ad-suite.pid"
)

foreach ($rel in $paths) {
    $full = Join-Path $ScriptRoot $rel
    if (Test-Path $full) {
        Remove-Item $full -Recurse -Force
        Write-Host "  Removed: $rel" -ForegroundColor Gray
    }
}

Write-Host "`nUninstall complete. Source code and suite scripts are untouched." -ForegroundColor Green

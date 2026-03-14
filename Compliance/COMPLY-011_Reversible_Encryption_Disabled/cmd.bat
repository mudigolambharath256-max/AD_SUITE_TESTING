@echo off
REM COMPLY-011: Reversible Encryption Disabled
echo [CMP-011] Reversible Encryption Disabled
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

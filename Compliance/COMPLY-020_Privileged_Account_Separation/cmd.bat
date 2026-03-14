@echo off
REM COMPLY-020: Privileged Account Separation
echo [CMP-020] Privileged Account Separation
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM CERT-034: Certificate Authority Health
echo [CERT-034] Certificate Authority Health
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM CERT-042: CA Certificate Expiration
echo [CERT-042] CA Certificate Expiration
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM CERT-048: Certificate Revocation Reasons
echo [CERT-048] Certificate Revocation Reasons
echo Severity: LOW ^| Risk: 4/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

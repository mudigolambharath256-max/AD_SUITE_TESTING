@echo off
REM CERT-050: Certificate Template EKU Misconfigurations
echo [CERT-050] Certificate Template EKU Misconfigurations
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM CERT-046: Certificate Template Permissions Excessive
echo [CERT-046] Certificate Template Permissions Excessive
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM CERT-053: CA Security Descriptor
echo [CERT-053] CA Security Descriptor
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

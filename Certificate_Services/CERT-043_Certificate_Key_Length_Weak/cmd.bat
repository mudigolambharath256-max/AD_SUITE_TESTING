@echo off
REM CERT-043: Certificate Key Length Weak
echo [CERT-043] Certificate Key Length Weak
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM CERT-052: Certificate Template Subject Name Issues
echo [CERT-052] Certificate Template Subject Name Issues
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

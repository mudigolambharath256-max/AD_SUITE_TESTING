@echo off
REM CERT-044: Certificate Validity Period Excessive
echo [CERT-044] Certificate Validity Period Excessive
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

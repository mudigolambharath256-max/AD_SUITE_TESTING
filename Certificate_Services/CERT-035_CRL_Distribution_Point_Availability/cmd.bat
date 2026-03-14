@echo off
REM CERT-035: CRL Distribution Point Availability
echo [CERT-035] CRL Distribution Point Availability
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

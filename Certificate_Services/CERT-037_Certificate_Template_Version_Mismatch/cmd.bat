@echo off
REM CERT-037: Certificate Template Version Mismatch
echo [CERT-037] Certificate Template Version Mismatch
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

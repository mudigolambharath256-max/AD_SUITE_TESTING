@echo off
REM CERT-051: CA Role Separation
echo [CERT-051] CA Role Separation
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

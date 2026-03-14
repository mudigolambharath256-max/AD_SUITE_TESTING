@echo off
REM CERT-045: CA Audit Settings
echo [CERT-045] CA Audit Settings
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM CERT-047: CA Database Backup Status
echo [CERT-047] CA Database Backup Status
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

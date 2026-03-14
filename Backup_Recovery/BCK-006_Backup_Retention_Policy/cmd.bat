@echo off
REM BCK-006: Backup Retention Policy
echo [BCK-006] Backup Retention Policy
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

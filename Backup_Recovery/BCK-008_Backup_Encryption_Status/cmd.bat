@echo off
REM BCK-008: Backup Encryption Status
echo [BCK-008] Backup Encryption Status
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

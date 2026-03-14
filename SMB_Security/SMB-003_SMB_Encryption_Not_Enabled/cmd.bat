@echo off
REM SMB-003: SMB Encryption Not Enabled
echo [SMB-003] SMB Encryption Not Enabled
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM SMB-008: SMB Shares with Weak Permissions
echo [SMB-008] SMB Shares with Weak Permissions
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

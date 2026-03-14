@echo off
REM SMB-006: SMB Guest Access Enabled
echo [SMB-006] SMB Guest Access Enabled
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

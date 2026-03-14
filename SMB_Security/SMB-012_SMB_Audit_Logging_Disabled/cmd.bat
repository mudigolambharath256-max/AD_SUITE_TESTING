@echo off
REM SMB-012: SMB Audit Logging Disabled
echo [SMB-012] SMB Audit Logging Disabled
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

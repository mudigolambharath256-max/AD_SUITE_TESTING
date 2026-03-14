@echo off
REM SMB-002: SMB Signing Not Required
echo [SMB-002] SMB Signing Not Required
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

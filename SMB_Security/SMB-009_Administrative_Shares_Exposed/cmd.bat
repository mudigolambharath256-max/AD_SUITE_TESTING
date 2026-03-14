@echo off
REM SMB-009: Administrative Shares Exposed
echo [SMB-009] Administrative Shares Exposed
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

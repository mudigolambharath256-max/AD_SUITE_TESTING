@echo off
REM SMB-001: SMBv1 Enabled
echo [SMB-001] SMBv1 Enabled
echo Severity: CRITICAL ^| Risk: 10/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

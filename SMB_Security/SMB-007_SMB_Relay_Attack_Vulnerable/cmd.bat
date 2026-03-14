@echo off
REM SMB-007: SMB Relay Attack Vulnerable
echo [SMB-007] SMB Relay Attack Vulnerable
echo Severity: CRITICAL ^| Risk: 9/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

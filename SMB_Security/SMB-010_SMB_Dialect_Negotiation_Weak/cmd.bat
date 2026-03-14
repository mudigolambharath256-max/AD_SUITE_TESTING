@echo off
REM SMB-010: SMB Dialect Negotiation Weak
echo [SMB-010] SMB Dialect Negotiation Weak
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

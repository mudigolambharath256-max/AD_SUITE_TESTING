@echo off
REM NET-002: Firewall Rules for AD Ports
echo [NET-002] Firewall Rules for AD Ports
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

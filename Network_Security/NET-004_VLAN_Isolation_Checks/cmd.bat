@echo off
REM NET-004: VLAN Isolation Checks
echo [NET-004] VLAN Isolation Checks
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

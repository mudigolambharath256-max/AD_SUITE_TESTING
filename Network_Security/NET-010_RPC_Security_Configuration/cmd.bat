@echo off
REM NET-010: RPC Security Configuration
echo [NET-010] RPC Security Configuration
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

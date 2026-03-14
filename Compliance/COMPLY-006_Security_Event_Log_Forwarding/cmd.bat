@echo off
REM COMPLY-006: Security Event Log Forwarding
echo [CMP-006] Security Event Log Forwarding
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

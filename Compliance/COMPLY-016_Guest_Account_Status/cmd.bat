@echo off
REM COMPLY-016: Guest Account Status
echo [CMP-016] Guest Account Status
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

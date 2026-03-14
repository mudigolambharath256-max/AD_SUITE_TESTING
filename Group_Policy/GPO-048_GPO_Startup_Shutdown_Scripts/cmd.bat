@echo off
REM GPO-048: GPO Startup Shutdown Scripts
echo [GPO-048] GPO Startup Shutdown Scripts
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

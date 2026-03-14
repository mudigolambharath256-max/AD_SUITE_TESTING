@echo off
REM GPO-044: GPO Scheduled Tasks Security
echo [GPO-044] GPO Scheduled Tasks Security
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

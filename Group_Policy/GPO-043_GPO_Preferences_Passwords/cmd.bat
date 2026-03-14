@echo off
REM GPO-043: GPO Preferences Passwords
echo [GPO-043] GPO Preferences Passwords
echo Severity: CRITICAL ^| Risk: 10/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

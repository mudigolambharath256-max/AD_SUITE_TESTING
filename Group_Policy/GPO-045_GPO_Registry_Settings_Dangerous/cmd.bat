@echo off
REM GPO-045: GPO Registry Settings Dangerous
echo [GPO-045] GPO Registry Settings Dangerous
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

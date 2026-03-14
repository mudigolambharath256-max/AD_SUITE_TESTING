@echo off
REM GPO-037: GPO Link Order Conflicts
echo [GPO-037] GPO Link Order Conflicts
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

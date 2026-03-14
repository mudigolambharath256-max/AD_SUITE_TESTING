@echo off
REM GPO-036: WMI Filter Validation
echo [GPO-036] WMI Filter Validation
echo Severity: LOW ^| Risk: 4/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

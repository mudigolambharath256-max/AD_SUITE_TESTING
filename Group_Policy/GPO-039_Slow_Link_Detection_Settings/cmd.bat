@echo off
REM GPO-039: Slow Link Detection Settings
echo [GPO-039] Slow Link Detection Settings
echo Severity: LOW ^| Risk: 3/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

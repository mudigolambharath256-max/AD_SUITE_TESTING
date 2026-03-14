@echo off
REM GPO-042: GPO Backup Status
echo [GPO-042] GPO Backup Status
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

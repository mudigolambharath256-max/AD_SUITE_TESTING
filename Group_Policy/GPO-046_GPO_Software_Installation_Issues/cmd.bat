@echo off
REM GPO-046: GPO Software Installation Issues
echo [GPO-046] GPO Software Installation Issues
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

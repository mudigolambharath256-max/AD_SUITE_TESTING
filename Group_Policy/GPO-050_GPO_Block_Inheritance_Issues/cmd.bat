@echo off
REM GPO-050: GPO Block Inheritance Issues
echo [GPO-050] GPO Block Inheritance Issues
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

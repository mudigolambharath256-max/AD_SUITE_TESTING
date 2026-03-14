@echo off
REM GPO-035: GPO Security Filtering Issues
echo [GPO-035] GPO Security Filtering Issues
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

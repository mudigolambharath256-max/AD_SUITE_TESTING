@echo off
REM GPO-040: GPO Processing Errors
echo [GPO-040] GPO Processing Errors
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

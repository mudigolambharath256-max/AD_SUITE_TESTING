@echo off
REM PERS-006: DSRM Password Changes
echo [PERS-006] DSRM Password Changes
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

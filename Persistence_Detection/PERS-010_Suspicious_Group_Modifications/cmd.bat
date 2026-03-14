@echo off
REM PERS-010: Suspicious Group Modifications
echo [PERS-010] Suspicious Group Modifications
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM PERS-011: ACL Backdoors
echo [PERS-011] ACL Backdoors
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

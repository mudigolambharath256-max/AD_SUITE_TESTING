@echo off
REM KRB-045: Protected Users Group Not Used
echo [KRB-045] Protected Users Group Not Used
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

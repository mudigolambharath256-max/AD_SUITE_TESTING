@echo off
REM AAD-034: Pass Through Authentication Security
echo [AAD-034] Pass Through Authentication Security
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

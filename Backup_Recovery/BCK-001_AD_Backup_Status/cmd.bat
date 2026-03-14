@echo off
REM BCK-001: AD Backup Status
echo [BCK-001] AD Backup Status
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

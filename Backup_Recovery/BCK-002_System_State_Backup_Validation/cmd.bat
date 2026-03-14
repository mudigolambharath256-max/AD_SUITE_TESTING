@echo off
REM BCK-002: System State Backup Validation
echo [BCK-002] System State Backup Validation
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM ADV-001: Print Spooler Service on DCs
echo [ADV-001] Print Spooler Service on DCs
echo Severity: CRITICAL ^| Risk: 10/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

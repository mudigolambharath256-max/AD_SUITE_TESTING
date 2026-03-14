@echo off
REM PERS-002: Golden Ticket Indicators
echo [PERS-002] Golden Ticket Indicators
echo Severity: CRITICAL ^| Risk: 10/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

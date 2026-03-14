@echo off
REM PERS-003: Silver Ticket Indicators
echo [PERS-003] Silver Ticket Indicators
echo Severity: HIGH ^| Risk: 9/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

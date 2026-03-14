@echo off
REM NET-009: Network Access Protection
echo [NET-009] Network Access Protection
echo Severity: LOW ^| Risk: 4/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

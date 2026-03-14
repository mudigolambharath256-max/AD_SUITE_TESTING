@echo off
REM AAD-040: Hybrid Identity Attack Surface
echo [AAD-040] Hybrid Identity Attack Surface
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

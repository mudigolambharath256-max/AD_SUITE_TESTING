@echo off
REM CERT-040: Web Enrollment Security
echo [CERT-040] Web Enrollment Security
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

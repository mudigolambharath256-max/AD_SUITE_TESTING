@echo off
REM ADV-010: Domain Trust Authentication Vulnerabilities
echo [ADV-010] Domain Trust Authentication Vulnerabilities
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

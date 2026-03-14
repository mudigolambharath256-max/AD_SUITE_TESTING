@echo off
REM ADV-009: ADCS Web Enrollment Vulnerabilities
echo [ADV-009] ADCS Web Enrollment Vulnerabilities
echo Severity: CRITICAL ^| Risk: 9/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

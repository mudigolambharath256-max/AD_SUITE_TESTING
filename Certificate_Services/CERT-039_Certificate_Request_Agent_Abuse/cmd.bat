@echo off
REM CERT-039: Certificate Request Agent Abuse
echo [CERT-039] Certificate Request Agent Abuse
echo Severity: CRITICAL ^| Risk: 9/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

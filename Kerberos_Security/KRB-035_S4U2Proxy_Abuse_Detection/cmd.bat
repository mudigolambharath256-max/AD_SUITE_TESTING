@echo off
REM KRB-035: S4U2Proxy Abuse Detection
echo [KRB-035] S4U2Proxy Abuse Detection
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

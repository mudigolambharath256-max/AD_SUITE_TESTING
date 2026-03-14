@echo off
REM AAD-035: Seamless SSO Configuration
echo [AAD-035] Seamless SSO Configuration
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

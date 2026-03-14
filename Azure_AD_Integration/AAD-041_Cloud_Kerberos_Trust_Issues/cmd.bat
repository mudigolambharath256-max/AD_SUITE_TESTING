@echo off
REM AAD-041: Cloud Kerberos Trust Issues
echo [AAD-041] Cloud Kerberos Trust Issues
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

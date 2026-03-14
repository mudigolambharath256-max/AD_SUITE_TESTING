@echo off
REM ADV-007: NTLM Relay Attack Surface
echo [ADV-007] NTLM Relay Attack Surface
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

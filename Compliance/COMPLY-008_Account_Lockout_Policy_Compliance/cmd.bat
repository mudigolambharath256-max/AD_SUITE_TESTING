@echo off
REM COMPLY-008: Account Lockout Policy Compliance
echo [CMP-008] Account Lockout Policy Compliance
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

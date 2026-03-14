@echo off
REM COMPLY-001: STIG Password Policy Compliance
echo [CMP-001] STIG Password Policy Compliance
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

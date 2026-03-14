@echo off
REM COMPLY-005: Advanced Audit Policy Validation
echo [CMP-005] Advanced Audit Policy Validation
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

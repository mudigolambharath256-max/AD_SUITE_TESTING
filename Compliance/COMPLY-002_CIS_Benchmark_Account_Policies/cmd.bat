@echo off
REM COMPLY-002: CIS Benchmark Account Policies
echo [CMP-002] CIS Benchmark Account Policies
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

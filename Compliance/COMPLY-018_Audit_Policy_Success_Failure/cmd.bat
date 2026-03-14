@echo off
REM COMPLY-018: Audit Policy Success Failure
echo [CMP-018] Audit Policy Success Failure
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

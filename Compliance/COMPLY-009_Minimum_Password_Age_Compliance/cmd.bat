@echo off
REM COMPLY-009: Minimum Password Age Compliance
echo [CMP-009] Minimum Password Age Compliance
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

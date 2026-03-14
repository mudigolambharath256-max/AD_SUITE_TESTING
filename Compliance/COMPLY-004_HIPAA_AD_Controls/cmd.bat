@echo off
REM COMPLY-004: HIPAA AD Controls
echo [CMP-004] HIPAA AD Controls
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

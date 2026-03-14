@echo off
REM COMPLY-007: Privileged Account Naming Convention
echo [CMP-007] Privileged Account Naming Convention
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

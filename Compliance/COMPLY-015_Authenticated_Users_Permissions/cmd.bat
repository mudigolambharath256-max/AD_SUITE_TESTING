@echo off
REM COMPLY-015: Authenticated Users Permissions
echo [CMP-015] Authenticated Users Permissions
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

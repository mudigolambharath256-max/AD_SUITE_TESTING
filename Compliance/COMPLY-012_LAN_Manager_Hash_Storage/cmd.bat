@echo off
REM COMPLY-012: LAN Manager Hash Storage
echo [CMP-012] LAN Manager Hash Storage
echo Severity: CRITICAL ^| Risk: 9/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

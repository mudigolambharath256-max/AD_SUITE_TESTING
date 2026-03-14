@echo off
REM COMPLY-017: Administrator Account Renamed
echo [CMP-017] Administrator Account Renamed
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

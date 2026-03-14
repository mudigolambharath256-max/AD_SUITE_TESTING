@echo off
REM PERS-001: DCShadow Attack Indicators
echo [PERS-001] DCShadow Attack Indicators
echo Severity: CRITICAL ^| Risk: 10/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

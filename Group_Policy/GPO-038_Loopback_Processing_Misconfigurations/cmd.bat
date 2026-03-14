@echo off
REM GPO-038: Loopback Processing Misconfigurations
echo [GPO-038] Loopback Processing Misconfigurations
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

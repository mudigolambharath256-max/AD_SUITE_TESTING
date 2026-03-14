@echo off
REM GPO-041: GPO Replication Issues
echo [GPO-041] GPO Replication Issues
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

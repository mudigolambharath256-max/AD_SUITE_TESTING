@echo off
REM SMB-005: Null Session Enumeration Possible
echo [SMB-005] Null Session Enumeration Possible
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

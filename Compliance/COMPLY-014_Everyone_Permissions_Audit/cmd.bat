@echo off
REM COMPLY-014: Everyone Permissions Audit
echo [CMP-014] Everyone Permissions Audit
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

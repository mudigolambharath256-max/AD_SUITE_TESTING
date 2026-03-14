@echo off
REM CMGMT-036: LAPS Passwords Expiring Soon
echo Running LAPS Passwords Expiring Soon...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

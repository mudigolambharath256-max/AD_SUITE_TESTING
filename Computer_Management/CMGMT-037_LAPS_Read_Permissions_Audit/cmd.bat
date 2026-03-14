@echo off
REM CMGMT-037: LAPS Read Permissions Audit
echo Running LAPS Read Permissions Audit...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

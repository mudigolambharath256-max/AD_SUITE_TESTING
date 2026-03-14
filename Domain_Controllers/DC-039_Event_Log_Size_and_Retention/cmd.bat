@echo off
REM DC-039: Event Log Size and Retention
echo Running Event Log Size and Retention...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

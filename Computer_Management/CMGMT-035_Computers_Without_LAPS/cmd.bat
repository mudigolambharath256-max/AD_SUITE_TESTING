@echo off
REM CMGMT-035: Computers Without LAPS
echo Running Computers Without LAPS...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

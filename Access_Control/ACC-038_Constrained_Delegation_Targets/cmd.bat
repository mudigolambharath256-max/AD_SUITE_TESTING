@echo off
REM ACC-038: Constrained Delegation Targets
echo Running Constrained Delegation Targets...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

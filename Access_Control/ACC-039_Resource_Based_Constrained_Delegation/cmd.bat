@echo off
REM ACC-039: Resource Based Constrained Delegation
echo Running Resource Based Constrained Delegation...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

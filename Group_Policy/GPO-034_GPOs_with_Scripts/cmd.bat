@echo off
REM GPO-034: GPOs with Scripts
echo Running GPOs with Scripts...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

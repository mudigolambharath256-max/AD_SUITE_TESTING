@echo off
REM GPO-033: Unlinked GPOs
echo Running Unlinked GPOs...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

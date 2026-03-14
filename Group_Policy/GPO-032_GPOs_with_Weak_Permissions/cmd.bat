@echo off
REM GPO-032: GPOs with Weak Permissions
echo Running GPOs with Weak Permissions...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

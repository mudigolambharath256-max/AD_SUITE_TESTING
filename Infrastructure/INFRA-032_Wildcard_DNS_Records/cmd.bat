@echo off
REM INFRA-032: Wildcard DNS Records
echo Running Wildcard DNS Records...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

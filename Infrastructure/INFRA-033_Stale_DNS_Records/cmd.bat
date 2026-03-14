@echo off
REM INFRA-033: Stale DNS Records
echo Running Stale DNS Records...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

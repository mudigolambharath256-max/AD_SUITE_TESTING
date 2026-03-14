@echo off
REM INFRA-031: DNS Records Pointing to External IPs
echo Running DNS Records Pointing to External IPs...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

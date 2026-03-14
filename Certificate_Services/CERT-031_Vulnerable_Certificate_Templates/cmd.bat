@echo off
REM CERT-031: Vulnerable Certificate Templates
echo Running Vulnerable Certificate Templates...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

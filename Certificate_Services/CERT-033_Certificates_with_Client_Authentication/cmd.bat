@echo off
REM CERT-033: Certificates with Client Authentication
echo Running Certificates with Client Authentication...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

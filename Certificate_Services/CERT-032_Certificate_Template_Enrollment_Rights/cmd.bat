@echo off
REM CERT-032: Certificate Template Enrollment Rights
echo Running Certificate Template Enrollment Rights...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

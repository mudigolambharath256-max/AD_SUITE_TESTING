@echo off
REM CMGMT-032: Computers with Cached Credentials
echo Running Computers with Cached Credentials...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

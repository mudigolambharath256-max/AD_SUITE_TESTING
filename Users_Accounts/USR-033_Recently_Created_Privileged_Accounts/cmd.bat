@echo off
REM USR-033: Recently Created Privileged Accounts
echo Running Recently Created Privileged Accounts...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

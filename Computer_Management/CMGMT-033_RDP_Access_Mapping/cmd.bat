@echo off
REM CMGMT-033: RDP Access Mapping
echo Running RDP Access Mapping...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM TMGMT-031: Trust Relationship Changes
echo Running Trust Relationship Changes...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

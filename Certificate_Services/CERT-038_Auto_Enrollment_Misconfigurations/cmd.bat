@echo off
REM CERT-038: Auto Enrollment Misconfigurations
echo [CERT-038] Auto Enrollment Misconfigurations
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

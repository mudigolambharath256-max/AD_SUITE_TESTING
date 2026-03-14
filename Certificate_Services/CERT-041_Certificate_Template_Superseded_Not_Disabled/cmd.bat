@echo off
REM CERT-041: Certificate Template Superseded Not Disabled
echo [CERT-041] Certificate Template Superseded Not Disabled
echo Severity: LOW ^| Risk: 3/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM COMPLY-003: PCI DSS AD Requirements
echo [CMP-003] PCI DSS AD Requirements
echo Severity: HIGH ^| Risk: 8/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

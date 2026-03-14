@echo off
REM KRB-041: Service Accounts with Unconstrained Delegation
echo [KRB-041] Service Accounts with Unconstrained Delegation
echo Severity: CRITICAL ^| Risk: 10/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM KRB-037: Unconstrained Delegation Computers
echo [KRB-037] Unconstrained Delegation Computers
echo Severity: CRITICAL ^| Risk: 9/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

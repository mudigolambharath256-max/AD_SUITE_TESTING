@echo off
REM NET-001: IPsec Policy Validation
echo [NET-001] IPsec Policy Validation
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

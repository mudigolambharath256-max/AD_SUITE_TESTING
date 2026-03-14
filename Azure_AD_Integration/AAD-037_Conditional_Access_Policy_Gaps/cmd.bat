@echo off
REM AAD-037: Conditional Access Policy Gaps
echo [AAD-037] Conditional Access Policy Gaps
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

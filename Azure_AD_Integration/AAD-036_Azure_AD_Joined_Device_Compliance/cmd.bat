@echo off
REM AAD-036: Azure AD Joined Device Compliance
echo [AAD-036] Azure AD Joined Device Compliance
echo Severity: MEDIUM ^| Risk: 5/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

@echo off
REM CERT-036: OCSP Responder Status
echo [CERT-036] OCSP Responder Status
echo Severity: MEDIUM ^| Risk: 6/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

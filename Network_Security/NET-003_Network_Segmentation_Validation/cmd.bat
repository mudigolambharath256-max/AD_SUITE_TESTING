@echo off
REM NET-003: Network Segmentation Validation
echo [NET-003] Network Segmentation Validation
echo Severity: HIGH ^| Risk: 7/10
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0powershell.ps1"
pause

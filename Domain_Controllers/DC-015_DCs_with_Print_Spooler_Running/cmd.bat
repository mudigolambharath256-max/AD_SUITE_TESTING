@echo off
REM Check: DCs with Print Spooler Running
REM Category: Domain Controllers
REM Severity: critical
REM ID: DC-015
REM Requirements: None
REM ============================================

echo === DCs with Print Spooler Running ===
echo.

REM Query all Domain Controllers
for /f "tokens=2 delims==" %%i in ('wmic /namespace:\\root\directory\ldap path ds_computer where "ds_userAccountControl='8192'" get ds_name /format:list ^| find "="') do (
    echo Checking DC: %%i
    
    REM Check Print Spooler service status
    sc \\%%i query spooler >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [WARNING] Print Spooler service found on %%i
        sc \\%%i query spooler | find "STATE"
    ) else (
        echo   [INFO] Unable to query Print Spooler service on %%i
    )
    echo.
)

echo Check completed.
pause
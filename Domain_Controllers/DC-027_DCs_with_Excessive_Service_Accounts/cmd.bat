@echo off
REM DC-051: DCs with Excessive Service Accounts
REM Identifies Domain Controllers with services running under domain accounts, which increases credential exposure risk.

echo DC-051: DCs with Excessive Service Accounts
echo ============================================================
echo.

REM Query Domain Controllers
for /f "tokens=*" %%i in ('dsquery server') do (
    echo Checking: %%i
    REM TODO: Implement specific check logic for DC-051
)

echo.
echo Check complete.
pause

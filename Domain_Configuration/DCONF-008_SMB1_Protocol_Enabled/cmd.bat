@echo off
REM ============================================================
REM CHECK: DCONF-008_SMB1_Protocol_Enabled
REM CATEGORY: Domain_Configuration
REM DESCRIPTION: Checks if SMB1 protocol is enabled (critical security risk)
REM LDAP FILTER: N/A (Registry check)
REM SEARCH BASE: N/A (Registry check)
REM OBJECT CLASS: N/A
REM ATTRIBUTES: N/A
REM RISK: CRITICAL
REM MITRE ATT&CK: T1021.002 (Remote Services: SMB/Windows Admin Shares)
REM ============================================================

echo [DCONF-008] Checking SMB1 Protocol Configuration...

REM Get list of domain controllers
for /f "tokens=2 delims= " %%i in ('dsquery server -domain %USERDNSDOMAIN%') do (
    set DC_NAME=%%i
    call :CheckDC !DC_NAME!
)

goto :EOF

:CheckDC
set DC=%~1
echo Checking DC: %DC%

REM Check SMB1 server registry setting
reg query "\\%DC%\HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v SMB1 2>nul | findstr "SMB1" >nul
if %ERRORLEVEL% EQU 0 (
    for /f "tokens=3" %%a in ('reg query "\\%DC%\HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v SMB1 2^>nul ^| findstr "SMB1"') do (
        if NOT "%%a"=="0x0" (
            echo [FINDING] %DC%: SMB1 Server enabled - CRITICAL RISK
        )
    )
) else (
    echo [FINDING] %DC%: SMB1 Server setting not found (may be enabled by default) - CRITICAL RISK
)

REM Check SMB1 client via mrxsmb10 service
reg query "\\%DC%\HKLM\SYSTEM\CurrentControlSet\Services\mrxsmb10" /v Start 2>nul | findstr "Start" >nul
if %ERRORLEVEL% EQU 0 (
    for /f "tokens=3" %%a in ('reg query "\\%DC%\HKLM\SYSTEM\CurrentControlSet\Services\mrxsmb10" /v Start 2^>nul ^| findstr "Start"') do (
        if NOT "%%a"=="0x4" (
            echo [FINDING] %DC%: SMB1 Client enabled (mrxsmb10) - CRITICAL RISK
        )
    )
)

goto :EOF
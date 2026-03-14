@echo off
REM ============================================================
REM CHECK: DCONF-007_NTLMv1_Protocol_Allowed
REM CATEGORY: Domain_Configuration
REM DESCRIPTION: Checks if NTLMv1 authentication is allowed (security risk)
REM LDAP FILTER: N/A (Registry check)
REM SEARCH BASE: N/A (Registry check)
REM OBJECT CLASS: N/A
REM ATTRIBUTES: N/A
REM RISK: HIGH
REM MITRE ATT&CK: T1557.001 (LLMNR/NBT-NS Poisoning and SMB Relay)
REM ============================================================

echo [DCONF-007] Checking NTLMv1 Protocol Configuration...

REM Get list of domain controllers
for /f "tokens=2 delims= " %%i in ('dsquery server -domain %USERDNSDOMAIN%') do (
    set DC_NAME=%%i
    call :CheckDC !DC_NAME!
)

goto :EOF

:CheckDC
set DC=%~1
echo Checking DC: %DC%

REM Query LmCompatibilityLevel registry value
reg query "\\%DC%\HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LmCompatibilityLevel 2>nul | findstr "LmCompatibilityLevel" >nul
if %ERRORLEVEL% EQU 0 (
    for /f "tokens=3" %%a in ('reg query "\\%DC%\HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LmCompatibilityLevel 2^>nul ^| findstr "LmCompatibilityLevel"') do (
        set LM_LEVEL=%%a
        if !LM_LEVEL! LSS 5 (
            echo [FINDING] %DC%: LmCompatibilityLevel=!LM_LEVEL! - NTLMv1 allowed
        )
    )
) else (
    echo [FINDING] %DC%: LmCompatibilityLevel=0 (default) - NTLMv1 allowed
)

goto :EOF
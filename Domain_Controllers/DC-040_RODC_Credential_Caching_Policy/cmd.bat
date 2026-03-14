@echo off
REM =============================================================================
REM DC-040: RODC Credential Caching Policy
REM =============================================================================
REM Category: Domain Controllers
REM Severity: HIGH
REM ID: DC-040
REM MITRE: T1552.004 (Unsecured Credentials: Private Keys)
REM =============================================================================
REM Description: Detects Read-Only Domain Controllers (RODCs) with insecure 
REM              credential caching policies using dsquery and dsget commands.
REM =============================================================================

echo ===============================================================================
echo DC-040: RODC Credential Caching Policy Check
echo ===============================================================================
echo.

REM Check if dsquery is available
dsquery computer -limit 1 >nul 2>&1
if errorlevel 1 (
    echo [ERROR] dsquery command not available. This check requires AD DS tools.
    echo [INFO] Install RSAT or run on a Domain Controller.
    exit /b 1
)

echo [INFO] Searching for Read-Only Domain Controllers...
echo.

REM Find RODCs using userAccountControl filter for PARTIAL_SECRETS_ACCOUNT (67108864)
REM Note: CMD/dsquery has limited bitwise operation support, so we use a broader search
dsquery computer -limit 0 | dsget computer -dn -samid -desc 2>nul | findstr /i "RODC\|ReadOnly\|Read-Only" >nul
if errorlevel 1 (
    echo [INFO] No RODCs found using description-based detection.
    echo [INFO] Attempting alternative detection method...
    echo.
)

REM Alternative: Search for computers with RODC-specific attributes
echo [INFO] Checking for computers with RODC characteristics...
echo.

REM Use dsquery to find computers and check their properties
for /f "tokens=*" %%i in ('dsquery computer -limit 0') do (
    REM Get computer properties
    for /f "tokens=*" %%j in ('dsget computer "%%i" -samid -desc 2^>nul ^| findstr /v "dsget succeeded"') do (
        echo Checking: %%j
        
        REM Check if this might be an RODC based on naming patterns
        echo %%j | findstr /i "RODC\|ReadOnly\|Read-Only" >nul
        if not errorlevel 1 (
            echo [POTENTIAL RODC FOUND] %%i
            echo   - Name: %%j
            echo   - Distinguished Name: %%i
            echo   - [WARNING] Manual verification required for RODC credential caching policy
            echo   - [RECOMMENDATION] Use PowerShell or ADSI methods for detailed analysis
            echo.
        )
    )
)

echo ===============================================================================
echo [LIMITATION] CMD/dsquery has limited capability for RODC policy analysis
echo [RECOMMENDATION] Use PowerShell (powershell.ps1) or ADSI (adsi.ps1) methods
echo                  for comprehensive RODC credential caching policy assessment
echo ===============================================================================
echo.

REM Provide guidance for manual verification
echo [MANUAL VERIFICATION STEPS]
echo 1. Identify RODCs: Get-ADComputer -Filter "userAccountControl -band 67108864"
echo 2. Check NeverRevealGroup: Get-ADComputer RODCNAME -Properties msDS-NeverRevealGroup
echo 3. Check RevealOnDemandGroup: Get-ADComputer RODCNAME -Properties msDS-RevealOnDemandGroup  
echo 4. Check RevealedList: Get-ADComputer RODCNAME -Properties msDS-RevealedList
echo 5. Verify privileged groups are in NeverRevealGroup
echo 6. Verify no privileged accounts are cached (RevealedList)
echo.

echo [SECURITY IMPACT]
echo - RODCs with weak credential caching policies risk privileged credential exposure
echo - Compromised RODC could yield cached Domain Admin or Enterprise Admin credentials
echo - Proper NeverRevealGroup configuration is critical for RODC security
echo.

exit /b 0
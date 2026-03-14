@echo off
REM ============================================================
REM CHECK: TRST-031_ExtraSIDs_Cross_Forest_Attack_Surface
REM CATEGORY: Trust_Relationships
REM DESCRIPTION: Detects forest trusts vulnerable to ExtraSIDs attacks
REM LDAP FILTER: (&(objectClass=trustedDomain)(trustType=2))
REM SEARCH BASE: CN=System,<DomainDN>
REM OBJECT CLASS: trustedDomain
REM ATTRIBUTES: trustPartner, trustDirection, trustType, trustAttributes, securityIdentifier
REM RISK: CRITICAL
REM MITRE ATT&CK: T1134.005 (Access Token Manipulation: SID-History Injection)
REM ============================================================

echo [TRST-031] Checking ExtraSIDs Cross Forest Attack Surface...

REM Query forest trusts (trustType=2)
echo Enumerating forest trusts...
dsquery * "CN=System,%USERDNSDOMAIN%" -filter "(&(objectClass=trustedDomain)(trustType=2))" -attr trustPartner trustDirection trustType trustAttributes distinguishedName > %TEMP%\forest_trusts.txt

if %ERRORLEVEL% NEQ 0 (
    echo Error: Could not query forest trusts
    exit /b 1
)

REM Process each forest trust
for /f "skip=1 tokens=1,2,3,4,5 delims=," %%a in (%TEMP%\forest_trusts.txt) do (
    set TRUST_PARTNER=%%a
    set TRUST_DIRECTION=%%b
    set TRUST_TYPE=%%c
    set TRUST_ATTRIBUTES=%%d
    set TRUST_DN=%%e
    
    call :AnalyzeTrust "!TRUST_PARTNER!" "!TRUST_DIRECTION!" "!TRUST_ATTRIBUTES!" "!TRUST_DN!"
)

REM Check for accounts with SID History (simplified check)
echo Checking for accounts with SID History...
dsquery user -domain %USERDNSDOMAIN% -o samid | findstr /v "^$" > %TEMP%\users.txt
for /f %%u in (%TEMP%\users.txt) do (
    dsget user "%%u" -sidhistory 2>nul | findstr /v "sidhistory" | findstr /v "^$" > nul
    if !ERRORLEVEL! EQU 0 (
        echo [FINDING] User %%u has SID History - potential ExtraSIDs vector
    )
)

REM Cleanup
del %TEMP%\forest_trusts.txt 2>nul
del %TEMP%\users.txt 2>nul

goto :EOF

:AnalyzeTrust
set PARTNER=%~1
set DIRECTION=%~2
set ATTRIBUTES=%~3
set DN=%~4

REM Convert hex attributes to decimal for bitwise operations (simplified)
REM Note: CMD batch has limited bitwise operations, this is a basic check

REM Check if trust direction allows inbound (1=inbound, 3=bidirectional)
if "%DIRECTION%"=="1" goto :CheckAttributes
if "%DIRECTION%"=="3" goto :CheckAttributes
goto :EOF

:CheckAttributes
REM Basic check for SID filtering (TREAT_AS_EXTERNAL bit 0x04)
REM This is a simplified check - full bitwise operations require PowerShell
echo Analyzing trust: %PARTNER%

REM If trustAttributes is 0 or doesn't contain quarantine bit, it's vulnerable
if "%ATTRIBUTES%"=="0" (
    echo [FINDING] %PARTNER%: SID filtering disabled - CRITICAL ExtraSIDs risk
) else (
    echo [INFO] %PARTNER%: Trust attributes = %ATTRIBUTES% - manual review recommended
)

goto :EOF
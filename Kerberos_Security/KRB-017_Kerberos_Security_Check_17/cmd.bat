REM Check: Kerberos Security Check 17
REM Category: Kerberos Security
REM Severity: medium
REM ID: KRB-017
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=user)(servicePrincipalName=*))" -limit 0 -attr name distinguishedName samAccountName servicePrincipalName

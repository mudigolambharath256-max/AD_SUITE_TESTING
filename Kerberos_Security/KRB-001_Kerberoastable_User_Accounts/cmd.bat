REM Check: Kerberoastable User Accounts
REM Category: Kerberos Security
REM Severity: high
REM ID: KRB-001
REM Requirements: dsquery (Windows RSAT DS Tools)
REM ============================================
REM NOTE: OID extensible match filters stripped (not supported by dsquery).
REM This cmd.bat returns structural inventory. Use adsi.ps1 for full detection.

@echo off
dsquery * -filter "(&(objectClass=user)(!)(servicePrincipalName=*))" -limit 0 -attr name distinguishedName samAccountName servicePrincipalName pwdLastSet

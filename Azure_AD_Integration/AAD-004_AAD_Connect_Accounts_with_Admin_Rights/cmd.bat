REM Check: AAD Connect Accounts with Admin Rights
REM Category: Azure AD Integration
REM Severity: critical
REM ID: AAD-004
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=MSOL_*)(samAccountName=AAD_*))(adminCount=1))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=MSOL_*)(samAccountName=AAD_*))(adminCount=1))" -limit 0 -attr name distinguishedname samaccountname admincount memberof

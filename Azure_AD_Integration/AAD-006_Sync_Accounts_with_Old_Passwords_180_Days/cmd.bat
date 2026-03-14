REM Check: Sync Accounts with Old Passwords (180+ Days)
REM Category: Azure AD Integration
REM Severity: medium
REM ID: AAD-006
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=MSOL_*)(samAccountName=AAD_*)))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=MSOL_*)(samAccountName=AAD_*)))" -limit 0 -attr name distinguishedname samaccountname pwdlastset

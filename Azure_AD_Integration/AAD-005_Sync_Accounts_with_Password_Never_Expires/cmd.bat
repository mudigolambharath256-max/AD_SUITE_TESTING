REM Check: Sync Accounts with Password Never Expires
REM Category: Azure AD Integration
REM Severity: high
REM ID: AAD-005
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=MSOL_*)(samAccountName=AAD_*))(userAccountControl:1.2.840.113556.1.4.803:=65536))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=MSOL_*)(samAccountName=AAD_*))(userAccountControl:1.2.840.113556.1.4.803:=65536))" -limit 0 -attr name distinguishedname samaccountname useraccountcontrol pwdlastset

REM Check: Sync Accounts in Domain Admins
REM Category: Azure AD Integration
REM Severity: critical
REM ID: AAD-017
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=MSOL_*)(samAccountName=AAD_*))(memberOf:1.2.840.113556.1.4.1941:=CN=Domain Admins,CN=Users,*))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=MSOL_*)(samAccountName=AAD_*))(memberOf:1.2.840.113556.1.4.1941:=CN=Domain Admins,CN=Users,*))" -limit 0 -attr name distinguishedname samaccountname memberof

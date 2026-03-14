REM Check: Password Hash Sync Enabled Indicators
REM Category: Azure AD Integration
REM Severity: high
REM ID: AAD-014
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(samAccountName=MSOL_*))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(samAccountName=MSOL_*))" -limit 0 -attr name distinguishedname samaccountname memberof

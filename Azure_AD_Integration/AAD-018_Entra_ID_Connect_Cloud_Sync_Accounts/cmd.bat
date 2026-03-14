REM Check: Entra ID Connect Cloud Sync Accounts
REM Category: Azure AD Integration
REM Severity: high
REM ID: AAD-018
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=*Provisioning*)(description=*cloud sync*)))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=*Provisioning*)(description=*cloud sync*)))" -limit 0 -attr name distinguishedname samaccountname description memberof

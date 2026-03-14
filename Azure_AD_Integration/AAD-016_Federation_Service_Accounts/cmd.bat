REM Check: Federation Service Accounts
REM Category: Azure AD Integration
REM Severity: high
REM ID: AAD-016
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=*ADFS*)(samAccountName=*adfssvc*)(description=*federation*)))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(samAccountName=*ADFS*)(samAccountName=*adfssvc*)(description=*federation*)))" -limit 0 -attr name distinguishedname samaccountname description serviceprincipalname

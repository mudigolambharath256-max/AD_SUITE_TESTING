REM Check: Accounts with Cloud Keywords in Description
REM Category: Azure AD Integration
REM Severity: low
REM ID: AAD-011
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(description=*azure*)(description=*Azure*)(description=*AAD*)(description=*cloud*)(description=*O365*)(description=*M365*)))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(|(description=*azure*)(description=*Azure*)(description=*AAD*)(description=*cloud*)(description=*O365*)(description=*M365*)))" -limit 0 -attr name distinguishedname samaccountname description

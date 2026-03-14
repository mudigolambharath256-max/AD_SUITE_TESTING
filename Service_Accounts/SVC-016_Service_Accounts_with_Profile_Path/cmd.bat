REM Check: Service Accounts with Profile Path
REM Category: Service Accounts
REM Severity: medium
REM ID: SVC-016
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(profilePath=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(profilePath=*))" -limit 0 -attr name distinguishedname samaccountname profilepath serviceprincipalname

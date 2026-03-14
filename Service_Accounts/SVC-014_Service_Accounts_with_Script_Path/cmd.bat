REM Check: Service Accounts with Script Path
REM Category: Service Accounts
REM Severity: low
REM ID: SVC-014
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(scriptPath=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(scriptPath=*))" -limit 0 -attr name distinguishedname samaccountname scriptpath serviceprincipalname

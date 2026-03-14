REM Check: Service Accounts Missing Description
REM Category: Service Accounts
REM Severity: info
REM ID: SVC-024
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(!(description=*)))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(!(description=*)))" -limit 0 -attr name distinguishedname samaccountname description serviceprincipalname

REM Check: Service Accounts with Home Directory
REM Category: Service Accounts
REM Severity: low
REM ID: SVC-015
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(homeDirectory=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(homeDirectory=*))" -limit 0 -attr name distinguishedname samaccountname homedirectory serviceprincipalname

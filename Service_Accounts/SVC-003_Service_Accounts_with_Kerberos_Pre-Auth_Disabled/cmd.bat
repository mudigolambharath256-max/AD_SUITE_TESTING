REM Check: Service Accounts with Kerberos Pre-Auth Disabled
REM Category: Service Accounts
REM Severity: critical
REM ID: SVC-003
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(userAccountControl:1.2.840.113556.1.4.803:=4194304))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(userAccountControl:1.2.840.113556.1.4.803:=4194304))" -limit 0 -attr name distinguishedname samaccountname useraccountcontrol serviceprincipalname

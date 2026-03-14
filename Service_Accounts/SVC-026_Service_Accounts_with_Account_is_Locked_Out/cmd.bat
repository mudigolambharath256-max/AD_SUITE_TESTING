REM Check: Service Accounts with “Account is Locked Out”
REM Category: Service Accounts
REM Severity: low
REM ID: SVC-026
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(lockoutTime>=1))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(lockoutTime>=1))" -limit 0 -attr name distinguishedname samaccountname lockouttime serviceprincipalname

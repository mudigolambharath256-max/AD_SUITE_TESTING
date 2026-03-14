REM Check: Service Accounts Marked adminCount=1
REM Category: Service Accounts
REM Severity: high
REM ID: SVC-009
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(adminCount=1))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(adminCount=1))" -limit 0 -attr name distinguishedname samaccountname admincount memberof serviceprincipalname

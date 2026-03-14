REM Check: Service Accounts not Marked “Sensitive and Cannot be Delegated”
REM Category: Service Accounts
REM Severity: medium
REM ID: SVC-018
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(!(userAccountControl:1.2.840.113556.1.4.803:=1048576)))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(!(userAccountControl:1.2.840.113556.1.4.803:=1048576)))" -limit 0 -attr name distinguishedname samaccountname useraccountcontrol serviceprincipalname

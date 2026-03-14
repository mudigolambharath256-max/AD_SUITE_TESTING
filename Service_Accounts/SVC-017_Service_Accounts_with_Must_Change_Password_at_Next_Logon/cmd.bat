REM Check: Service Accounts with “Must Change Password at Next Logon”
REM Category: Service Accounts
REM Severity: medium
REM ID: SVC-017
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(pwdLastSet=0))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(pwdLastSet=0))" -limit 0 -attr name distinguishedname samaccountname pwdlastset serviceprincipalname

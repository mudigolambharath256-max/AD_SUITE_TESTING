REM Check: Service Accounts (SPN Inventory)
REM Category: Service Accounts
REM Severity: info
REM ID: SVC-001
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2))))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2))))" -limit 0 -attr name distinguishedname samaccountname serviceprincipalname description

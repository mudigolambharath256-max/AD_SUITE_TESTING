REM Check: Accounts Requiring Password Change
REM Category: Authentication
REM Severity: low
REM ID: AUTH-006
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(pwdLastSet=0))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(pwdLastSet=0))" -limit 0 -attr name distinguishedname samaccountname pwdlastset

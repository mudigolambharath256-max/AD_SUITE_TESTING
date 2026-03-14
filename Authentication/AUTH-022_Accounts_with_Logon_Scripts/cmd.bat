REM Check: Accounts with Logon Scripts
REM Category: Authentication
REM Severity: low
REM ID: AUTH-022
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(scriptPath=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(scriptPath=*))" -limit 0 -attr name distinguishedname samaccountname scriptpath

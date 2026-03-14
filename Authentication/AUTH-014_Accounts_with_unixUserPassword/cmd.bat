REM Check: Accounts with unixUserPassword
REM Category: Authentication
REM Severity: high
REM ID: AUTH-014
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(unixUserPassword=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(unixUserPassword=*))" -limit 0 -attr name distinguishedname samaccountname unixuserpassword

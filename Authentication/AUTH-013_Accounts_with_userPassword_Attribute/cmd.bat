REM Check: Accounts with userPassword Attribute
REM Category: Authentication
REM Severity: critical
REM ID: AUTH-013
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(userPassword=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(userPassword=*))" -limit 0 -attr name distinguishedname samaccountname userpassword

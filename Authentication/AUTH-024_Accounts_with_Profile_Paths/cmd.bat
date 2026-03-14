REM Check: Accounts with Profile Paths
REM Category: Authentication
REM Severity: info
REM ID: AUTH-024
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(profilePath=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(profilePath=*))" -limit 0 -attr name distinguishedname samaccountname profilepath

REM Check: Accounts with Home Directories
REM Category: Authentication
REM Severity: info
REM ID: AUTH-023
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(homeDirectory=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(homeDirectory=*))" -limit 0 -attr name distinguishedname samaccountname homedirectory

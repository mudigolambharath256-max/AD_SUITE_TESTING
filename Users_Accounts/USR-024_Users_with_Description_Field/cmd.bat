REM Check: Users with Description Field
REM Category: Users & Accounts
REM Severity: low
REM ID: USR-024
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(description=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(description=*))" -limit 0 -attr name distinguishedname samaccountname description

REM Check: Computers with SIDHistory
REM Category: Computers & Servers
REM Severity: high
REM ID: CMP-009
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(sIDHistory=*))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(sIDHistory=*))" -limit 0 -attr name distinguishedname samaccountname sidhistory

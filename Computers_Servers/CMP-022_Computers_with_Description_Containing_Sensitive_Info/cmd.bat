REM Check: Computers with Description Containing Sensitive Info
REM Category: Computers & Servers
REM Severity: low
REM ID: CMP-022
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(description=*))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(description=*))" -limit 0 -attr name distinguishedname samaccountname description

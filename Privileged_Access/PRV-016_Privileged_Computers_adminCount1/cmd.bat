REM Check: Privileged Computers (adminCount=1)
REM Category: Privileged Access
REM Severity: high
REM ID: PRV-016
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(adminCount=1))

dsquery * -filter "(&(objectCategory=computer)(adminCount=1))" -limit 0 -attr name distinguishedname samaccountname admincount operatingsystem

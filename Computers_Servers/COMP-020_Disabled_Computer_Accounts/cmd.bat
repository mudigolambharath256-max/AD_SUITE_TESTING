REM Check: Disabled Computer Accounts
REM Category: Computers & Servers
REM Severity: low
REM ID: COMP-020
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=2))

dsquery * -filter "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=2))" -limit 0 -attr name distinguishedname samaccountname whenchanged operatingsystem

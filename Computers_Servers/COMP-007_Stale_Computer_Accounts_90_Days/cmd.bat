REM Check: Stale Computer Accounts (90+ Days)
REM Category: Computers & Servers
REM Severity: medium
REM ID: COMP-007
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))" -limit 0 -attr name distinguishedname samaccountname lastlogontimestamp pwdlastset operatingsystem

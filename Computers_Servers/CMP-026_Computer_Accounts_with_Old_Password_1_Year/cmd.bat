REM Check: Computer Accounts with Old Password (1+ Year)
REM Category: Computers & Servers
REM Severity: medium
REM ID: CMP-026
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))" -limit 0 -attr name distinguishedname samaccountname pwdlastset operatingsystem

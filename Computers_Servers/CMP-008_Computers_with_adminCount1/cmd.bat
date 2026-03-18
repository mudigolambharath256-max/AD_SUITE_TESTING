REM Check: Computers with adminCount1
REM Category: Computers & Servers
REM Severity: high
REM ID: CMP-008
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))" -limit 0 -attr name distinguishedname samaccountname admincount operatingsystem

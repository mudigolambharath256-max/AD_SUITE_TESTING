REM Check: Privileged Users (adminCount=1)
REM Category: Privileged Access
REM Severity: high
REM ID: PRV-015
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(adminCount=1))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(adminCount=1))" -limit 0 -attr name distinguishedname samaccountname admincount memberof pwdlastset

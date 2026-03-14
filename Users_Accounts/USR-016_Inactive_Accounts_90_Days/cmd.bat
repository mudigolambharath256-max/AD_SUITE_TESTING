REM Check: Inactive Accounts (90+ Days)
REM Category: Users & Accounts
REM Severity: medium
REM ID: USR-016
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))" -limit 0 -attr name distinguishedname samaccountname lastlogontimestamp pwdlastset

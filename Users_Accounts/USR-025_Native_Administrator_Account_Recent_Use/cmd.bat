REM Check: Native Administrator Account Recent Use
REM Category: Users & Accounts
REM Severity: medium
REM ID: USR-025
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(objectSid=*-500))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(objectSid=*-500))" -limit 0 -attr name distinguishedname samaccountname lastlogontimestamp pwdlastset

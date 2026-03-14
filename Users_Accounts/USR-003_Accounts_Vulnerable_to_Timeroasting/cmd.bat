REM Check: Accounts Vulnerable to Timeroasting
REM Category: Users & Accounts
REM Severity: high
REM ID: USR-003
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(userPassword=*))

dsquery * -filter "(&(objectCategory=computer)(userPassword=*))" -limit 0 -attr name distinguishedname samaccountname userpassword

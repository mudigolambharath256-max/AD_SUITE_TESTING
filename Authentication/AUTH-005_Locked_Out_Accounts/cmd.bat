REM Check: Locked Out Accounts
REM Category: Authentication
REM Severity: medium
REM ID: AUTH-005
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(lockoutTime>=1))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(lockoutTime>=1))" -limit 0 -attr name distinguishedname samaccountname lockouttime badpwdcount

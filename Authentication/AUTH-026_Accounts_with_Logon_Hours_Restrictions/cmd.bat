REM Check: Accounts with Logon Hours Restrictions
REM Category: Authentication
REM Severity: info
REM ID: AUTH-026
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(logonHours=*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(logonHours=*))" -limit 0 -attr name distinguishedname samaccountname logonhours

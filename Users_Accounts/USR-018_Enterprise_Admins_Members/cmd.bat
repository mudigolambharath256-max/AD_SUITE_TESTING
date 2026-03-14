REM Check: Enterprise Admins Members
REM Category: Users & Accounts
REM Severity: critical
REM ID: USR-018
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=CN=Enterprise Admins,CN=Users,*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=CN=Enterprise Admins,CN=Users,*))" -limit 0 -attr name distinguishedname samaccountname memberof

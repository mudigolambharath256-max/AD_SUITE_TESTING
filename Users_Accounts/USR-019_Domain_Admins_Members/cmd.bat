REM Check: Domain Admins Members
REM Category: Users & Accounts
REM Severity: high
REM ID: USR-019
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=CN=Domain Admins,CN=Users,*))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=CN=Domain Admins,CN=Users,*))" -limit 0 -attr name distinguishedname samaccountname memberof lastlogontimestamp

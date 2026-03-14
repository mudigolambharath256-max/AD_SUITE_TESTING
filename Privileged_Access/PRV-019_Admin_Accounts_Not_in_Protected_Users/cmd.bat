REM Check: Admin Accounts Not in Protected Users
REM Category: Privileged Access
REM Severity: high
REM ID: PRV-019
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(adminCount=1)(!(memberOf:1.2.840.113556.1.4.1941:=CN=Protected Users,CN=Users,*)))

dsquery * -filter "(&(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))(adminCount=1)(!(memberOf:1.2.840.113556.1.4.1941:=CN=Protected Users,CN=Users,*)))" -limit 0 -attr name distinguishedname samaccountname memberof

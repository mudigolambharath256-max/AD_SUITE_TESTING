REM Check: Membership: Cert Publishers
REM Category: Privileged Access
REM Severity: high
REM ID: PRV-011
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Cert Publishers))

dsquery * -filter "(&(objectCategory=group)(cn=Cert Publishers))" -limit 0 -attr name distinguishedname cn member

REM Check: Membership: Administrators
REM Category: Privileged Access
REM Severity: critical
REM ID: PRV-004
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Administrators))

dsquery * -filter "(&(objectCategory=group)(cn=Administrators))" -limit 0 -attr name distinguishedname cn member

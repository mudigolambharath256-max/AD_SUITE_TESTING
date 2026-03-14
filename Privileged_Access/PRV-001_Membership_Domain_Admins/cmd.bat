REM Check: Membership: Domain Admins
REM Category: Privileged Access
REM Severity: critical
REM ID: PRV-001
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Domain Admins))

dsquery * -filter "(&(objectCategory=group)(cn=Domain Admins))" -limit 0 -attr name distinguishedname cn member

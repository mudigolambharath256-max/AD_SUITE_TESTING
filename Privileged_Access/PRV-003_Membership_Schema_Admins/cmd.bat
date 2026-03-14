REM Check: Membership: Schema Admins
REM Category: Privileged Access
REM Severity: critical
REM ID: PRV-003
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Schema Admins))

dsquery * -filter "(&(objectCategory=group)(cn=Schema Admins))" -limit 0 -attr name distinguishedname cn member

REM Check: Membership: Backup Operators
REM Category: Privileged Access
REM Severity: high
REM ID: PRV-006
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Backup Operators))

dsquery * -filter "(&(objectCategory=group)(cn=Backup Operators))" -limit 0 -attr name distinguishedname cn member

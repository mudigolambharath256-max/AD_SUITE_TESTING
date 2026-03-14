REM Check: Membership: Account Operators
REM Category: Privileged Access
REM Severity: high
REM ID: PRV-005
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Account Operators))

dsquery * -filter "(&(objectCategory=group)(cn=Account Operators))" -limit 0 -attr name distinguishedname cn member

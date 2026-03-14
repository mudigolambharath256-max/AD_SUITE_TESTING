REM Check: Membership: Print Operators
REM Category: Privileged Access
REM Severity: high
REM ID: PRV-008
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Print Operators))

dsquery * -filter "(&(objectCategory=group)(cn=Print Operators))" -limit 0 -attr name distinguishedname cn member

REM Check: Membership: Server Operators
REM Category: Privileged Access
REM Severity: high
REM ID: PRV-007
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Server Operators))

dsquery * -filter "(&(objectCategory=group)(cn=Server Operators))" -limit 0 -attr name distinguishedname cn member

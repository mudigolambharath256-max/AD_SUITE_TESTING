REM Check: Membership: Remote Desktop Users
REM Category: Privileged Access
REM Severity: medium
REM ID: PRV-012
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Remote Desktop Users))

dsquery * -filter "(&(objectCategory=group)(cn=Remote Desktop Users))" -limit 0 -attr name distinguishedname cn member

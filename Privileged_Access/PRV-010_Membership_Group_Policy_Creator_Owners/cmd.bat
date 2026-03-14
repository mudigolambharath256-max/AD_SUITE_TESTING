REM Check: Membership: Group Policy Creator Owners
REM Category: Privileged Access
REM Severity: high
REM ID: PRV-010
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Group Policy Creator Owners))

dsquery * -filter "(&(objectCategory=group)(cn=Group Policy Creator Owners))" -limit 0 -attr name distinguishedname cn member

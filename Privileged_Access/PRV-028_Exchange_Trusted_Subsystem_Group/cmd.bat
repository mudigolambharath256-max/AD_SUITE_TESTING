REM Check: Exchange Trusted Subsystem Group
REM Category: Privileged Access
REM Severity: high
REM ID: PRV-028
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Exchange Trusted Subsystem))

dsquery * -filter "(&(objectCategory=group)(cn=Exchange Trusted Subsystem))" -limit 0 -attr name distinguishedname cn member

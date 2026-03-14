REM Check: Exchange Windows Permissions Group
REM Category: Privileged Access
REM Severity: critical
REM ID: PRV-027
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Exchange Windows Permissions))

dsquery * -filter "(&(objectCategory=group)(cn=Exchange Windows Permissions))" -limit 0 -attr name distinguishedname cn member

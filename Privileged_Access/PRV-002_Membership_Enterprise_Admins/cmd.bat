REM Check: Membership: Enterprise Admins
REM Category: Privileged Access
REM Severity: critical
REM ID: PRV-002
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Enterprise Admins))

dsquery * -filter "(&(objectCategory=group)(cn=Enterprise Admins))" -limit 0 -attr name distinguishedname cn member

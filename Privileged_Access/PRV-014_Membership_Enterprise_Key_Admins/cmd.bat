REM Check: Membership: Enterprise Key Admins
REM Category: Privileged Access
REM Severity: high
REM ID: PRV-014
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Enterprise Key Admins))

dsquery * -filter "(&(objectCategory=group)(cn=Enterprise Key Admins))" -limit 0 -attr name distinguishedname cn member

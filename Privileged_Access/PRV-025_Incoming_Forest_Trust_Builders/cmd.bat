REM Check: Incoming Forest Trust Builders
REM Category: Privileged Access
REM Severity: high
REM ID: PRV-025
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Incoming Forest Trust Builders))

dsquery * -filter "(&(objectCategory=group)(cn=Incoming Forest Trust Builders))" -limit 0 -attr name distinguishedname cn member

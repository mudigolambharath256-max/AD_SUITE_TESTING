REM Check: AdminSDHolder Object
REM Category: Privileged Access
REM Severity: info
REM ID: PRV-026
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=container)(cn=AdminSDHolder))

dsquery * -filter "(&(objectClass=container)(cn=AdminSDHolder))" -limit 0 -attr name distinguishedname cn ntsecuritydescriptor

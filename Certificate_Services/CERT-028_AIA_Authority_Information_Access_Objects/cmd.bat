REM Check: AIA (Authority Information Access) Objects
REM Category: Certificate Services
REM Severity: info
REM ID: CERT-028
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=container)(cn=AIA))

dsquery * -filter "(&(objectClass=container)(cn=AIA))" -limit 0 -attr name distinguishedname cn

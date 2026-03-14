REM Check: Protected Users Group Members
REM Category: Privileged Access
REM Severity: info
REM ID: PRV-021
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Protected Users))

dsquery * -filter "(&(objectCategory=group)(cn=Protected Users))" -limit 0 -attr name distinguishedname cn member

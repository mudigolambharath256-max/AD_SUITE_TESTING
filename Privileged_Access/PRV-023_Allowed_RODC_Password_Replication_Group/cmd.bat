REM Check: Allowed RODC Password Replication Group
REM Category: Privileged Access
REM Severity: medium
REM ID: PRV-023
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Allowed RODC Password Replication Group))

dsquery * -filter "(&(objectCategory=group)(cn=Allowed RODC Password Replication Group))" -limit 0 -attr name distinguishedname cn member

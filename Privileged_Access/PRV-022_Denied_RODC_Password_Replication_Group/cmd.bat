REM Check: Denied RODC Password Replication Group
REM Category: Privileged Access
REM Severity: info
REM ID: PRV-022
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=Denied RODC Password Replication Group))

dsquery * -filter "(&(objectCategory=group)(cn=Denied RODC Password Replication Group))" -limit 0 -attr name distinguishedname cn member

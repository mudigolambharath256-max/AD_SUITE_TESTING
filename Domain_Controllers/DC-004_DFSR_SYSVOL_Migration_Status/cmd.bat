@echo off
REM Check: DFSR SYSVOL Migration Status
REM Category: Domain Controllers
REM Severity: info
REM ID: DC-004
REM Requirements: dsquery (RSAT DS tools)
REM ============================================


REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=msDFSR-ReplicationGroup)(cn=Domain System Volume))

dsquery * -filter "(&(objectClass=msDFSR-ReplicationGroup)(cn=Domain System Volume))" -limit 0 -attr name distinguishedname cn msdfsr-replicationgrouptype

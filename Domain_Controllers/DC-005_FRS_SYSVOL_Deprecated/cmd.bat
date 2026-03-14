@echo off
REM Check: FRS SYSVOL (Deprecated)
REM Category: Domain Controllers
REM Severity: high
REM ID: DC-005
REM Requirements: dsquery (RSAT DS tools)
REM ============================================


REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=nTFRSReplicaSet)(cn=Domain System Volume*))

dsquery * -filter "(&(objectClass=nTFRSReplicaSet)(cn=Domain System Volume*))" -limit 0 -attr name distinguishedname cn

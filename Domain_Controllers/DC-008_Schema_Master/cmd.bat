@echo off
REM Check: Schema Master
REM Category: Domain Controllers
REM Severity: info
REM ID: DC-008
REM Requirements: dsquery (RSAT DS tools)
REM ============================================
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=dMD)
dsquery * "CN=Schema,CN=Configuration,DC=Mahishmati,DC=org" -scope base -filter "(objectClass=dMD)" -limit 0 -attr name distinguishedname fsmoroleowner
REM Check: Starter GPOs
REM Category: Group Policy
REM Severity: info
REM ID: GPO-016
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=msGPOsForConfiguration)

dsquery * -filter "(objectClass=msGPOsForConfiguration)" -limit 0 -attr name distinguishedname cn

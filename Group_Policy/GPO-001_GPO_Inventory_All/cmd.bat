REM Check: GPO Inventory (All)
REM Category: Group Policy
REM Severity: info
REM ID: GPO-001
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=groupPolicyContainer)

dsquery * -filter "(objectClass=groupPolicyContainer)" -limit 0 -attr name distinguishedname displayname gpcfilesyspath versionnumber flags whencreated

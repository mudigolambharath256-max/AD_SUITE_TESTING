REM Check: Default Domain Controllers Policy
REM Category: Group Policy
REM Severity: info
REM ID: GPO-008
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(cn={6AC1786C-016F-11D2-945F-00C04fB984F9}))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(cn={6AC1786C-016F-11D2-945F-00C04fB984F9}))" -limit 0 -attr name distinguishedname displayname versionnumber gpcfilesyspath

REM Check: Default Domain Policy
REM Category: Group Policy
REM Severity: info
REM ID: GPO-007
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(cn={31B2F340-016D-11D2-945F-00C04FB984F9}))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(cn={31B2F340-016D-11D2-945F-00C04FB984F9}))" -limit 0 -attr name distinguishedname displayname versionnumber gpcfilesyspath

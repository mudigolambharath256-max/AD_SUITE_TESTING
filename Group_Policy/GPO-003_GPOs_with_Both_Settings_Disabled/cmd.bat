REM Check: GPOs with Both Settings Disabled
REM Category: Group Policy
REM Severity: medium
REM ID: GPO-003
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=groupPolicyContainer)(flags=3))

dsquery * -filter "(&(objectClass=groupPolicyContainer)(flags=3))" -limit 0 -attr name distinguishedname displayname flags whenchanged

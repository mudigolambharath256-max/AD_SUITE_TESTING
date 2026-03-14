REM Check: GPOs Modified Recently
REM Category: Group Policy
REM Severity: info
REM ID: GPO-010
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=groupPolicyContainer)

dsquery * -filter "(objectClass=groupPolicyContainer)" -limit 0 -attr name distinguishedname displayname whenchanged versionnumber

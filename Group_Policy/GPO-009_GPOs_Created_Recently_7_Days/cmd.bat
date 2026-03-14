REM Check: GPOs Created Recently (7 Days)
REM Category: Group Policy
REM Severity: info
REM ID: GPO-009
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=groupPolicyContainer)

dsquery * -filter "(objectClass=groupPolicyContainer)" -limit 0 -attr name distinguishedname displayname whencreated gpcfilesyspath

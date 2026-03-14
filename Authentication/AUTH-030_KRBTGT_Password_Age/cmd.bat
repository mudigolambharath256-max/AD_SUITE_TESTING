REM Check: KRBTGT Password Age
REM Category: Authentication
REM Severity: high
REM ID: AUTH-030
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(samAccountName=krbtgt))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(samAccountName=krbtgt))" -limit 0 -attr name distinguishedname samaccountname pwdlastset

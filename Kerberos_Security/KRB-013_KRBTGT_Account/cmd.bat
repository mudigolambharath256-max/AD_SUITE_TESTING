REM Check: KRBTGT Account
REM Category: Kerberos Security
REM Severity: info
REM ID: KRB-013
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(samAccountName=krbtgt))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(samAccountName=krbtgt))" -limit 0 -attr name distinguishedname samaccountname pwdlastset

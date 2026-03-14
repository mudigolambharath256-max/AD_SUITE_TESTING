REM Check: DCs with Unsigned LDAP Binds Allowed
REM Category: Domain Controllers
REM Severity: high
REM ID: DC-042
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))

dsquery * -filter "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))" -limit 0 -attr name distinguishedname dnshostname operatingsystem


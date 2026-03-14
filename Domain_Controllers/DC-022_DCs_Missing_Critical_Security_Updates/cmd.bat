REM Check: DCs Missing Critical Security Updates
REM Category: Domain Controllers
REM Severity: critical
REM ID: DC-046
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))

dsquery * -filter "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))" -limit 0 -attr name distinguishedname dnshostname operatingsystem


REM Check: Native Guest Account
REM Category: Authentication
REM Severity: low
REM ID: AUTH-020
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(objectSid=*-501))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(objectSid=*-501))" -limit 0 -attr name distinguishedname samaccountname useraccountcontrol

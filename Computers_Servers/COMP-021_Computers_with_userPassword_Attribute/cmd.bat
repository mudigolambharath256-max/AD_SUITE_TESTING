REM Check: Computers with userPassword Attribute
REM Category: Computers & Servers
REM Severity: high
REM ID: COMP-021
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(userPassword=*))

dsquery * -filter "(&(objectCategory=computer)(userPassword=*))" -limit 0 -attr name distinguishedname samaccountname userpassword

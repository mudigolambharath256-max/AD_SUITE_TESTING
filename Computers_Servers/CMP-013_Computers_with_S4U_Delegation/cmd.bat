REM Check: Computers with S4U Delegation
REM Category: Computers & Servers
REM Severity: high
REM ID: CMP-013
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=16777216))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=16777216))" -limit 0 -attr name distinguishedname samaccountname useraccountcontrol msds-allowedtodelegateto

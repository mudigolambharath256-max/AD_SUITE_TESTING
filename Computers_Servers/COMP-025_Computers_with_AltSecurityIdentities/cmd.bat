REM Check: Computers with AltSecurityIdentities
REM Category: Computers & Servers
REM Severity: medium
REM ID: COMP-025
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(altSecurityIdentities=*))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(altSecurityIdentities=*))" -limit 0 -attr name distinguishedname samaccountname altsecurityidentities

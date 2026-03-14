REM Check: Computers with Constrained Delegation
REM Category: Computers & Servers
REM Severity: high
REM ID: COMP-002
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToDelegateTo=*))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToDelegateTo=*))" -limit 0 -attr name distinguishedname samaccountname msds-allowedtodelegateto operatingsystem
REM Check: Computers with Protocol Transition
REM Category: Kerberos Security
REM Severity: high
REM ID: KRB-025
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=16777216))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=16777216))" -limit 0 -attr name distinguishedname samaccountname msds-allowedtodelegateto operatingsystem

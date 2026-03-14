REM Check: Protocol Transition (S4U2Self)
REM Category: Kerberos Security
REM Severity: high
REM ID: KRB-007
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=16777216))

dsquery * -filter "(&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=16777216))" -limit 0 -attr name distinguishedname samaccountname objectclass msds-allowedtodelegateto

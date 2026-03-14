REM Check: Accounts Vulnerable to ASRepRoasting
REM Category: Users & Accounts
REM Severity: critical
REM ID: USR-001
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=4194304))

dsquery * -filter "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=4194304))" -limit 0 -attr name distinguishedname samaccountname useraccountcontrol

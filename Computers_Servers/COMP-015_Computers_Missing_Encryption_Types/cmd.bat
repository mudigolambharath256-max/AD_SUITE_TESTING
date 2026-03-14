REM Check: Computers Missing Encryption Types
REM Category: Computers & Servers
REM Severity: medium
REM ID: COMP-015
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(!(msDS-SupportedEncryptionTypes=*)))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(!(msDS-SupportedEncryptionTypes=*)))" -limit 0 -attr name distinguishedname samaccountname operatingsystem

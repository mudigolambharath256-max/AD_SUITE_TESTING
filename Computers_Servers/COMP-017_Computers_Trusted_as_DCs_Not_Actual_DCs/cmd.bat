REM Check: Computers Trusted as DCs (Not Actual DCs)
REM Category: Computers & Servers
REM Severity: critical
REM ID: COMP-017
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=8192)(!(primaryGroupID=516)))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=8192)(!(primaryGroupID=516)))" -limit 0 -attr name distinguishedname samaccountname useraccountcontrol primarygroupid

REM Check: Windows Servers Inventory
REM Category: Computers & Servers
REM Severity: info
REM ID: CMP-011
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(operatingSystem=*Server*))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(operatingSystem=*Server*))" -limit 0 -attr name distinguishedname samaccountname operatingsystem operatingsystemversion lastlogontimestamp

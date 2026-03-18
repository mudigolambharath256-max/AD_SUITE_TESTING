REM Check: Computers - Windows 10 Versions
REM Category: Computers & Servers
REM Severity: info
REM ID: CMP-027
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(operatingSystem=*Windows 10*))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(operatingSystem=*Windows 10*))" -limit 0 -attr name distinguishedname samaccountname operatingsystem operatingsystemversion

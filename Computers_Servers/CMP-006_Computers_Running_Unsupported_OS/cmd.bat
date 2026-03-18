REM Check: Computers Running Unsupported OS
REM Category: Computers & Servers
REM Severity: critical
REM ID: CMP-006
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(|(operatingSystem=*XP*)(operatingSystem=*Vista*)(operatingSystem=*Windows 7*)(operatingSystem=*2003*)(operatingSystem=*2008*)(operatingSystem=*2012 *)))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(|(operatingSystem=*XP*)(operatingSystem=*Vista*)(operatingSystem=*Windows 7*)(operatingSystem=*2003*)(operatingSystem=*2008*)(operatingSystem=*2012 *)))" -limit 0 -attr name distinguishedname samaccountname operatingsystem operatingsystemversion lastlogontimestamp

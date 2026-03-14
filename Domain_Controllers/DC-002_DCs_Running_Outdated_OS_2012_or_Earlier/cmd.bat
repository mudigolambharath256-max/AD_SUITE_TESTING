REM Check: DCs Running Outdated OS (2012 or Earlier)
REM Category: Domain Controllers
REM Severity: critical
REM ID: DC-004
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(|(operatingSystem=*2003*)(operatingSystem=*2008*)(operatingSystem=*2012*)))

dsquery * -filter "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(|(operatingSystem=*2003*)(operatingSystem=*2008*)(operatingSystem=*2012*)))" -limit 0 -attr name distinguishedname samaccountname operatingsystem operatingsystemversion

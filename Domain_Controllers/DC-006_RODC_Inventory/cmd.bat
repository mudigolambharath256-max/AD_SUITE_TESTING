REM Check: RODC Inventory
REM Category: Domain Controllers
REM Severity: info
REM ID: DC-006
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(primaryGroupID=521))

dsquery * -filter "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(primaryGroupID=521))" -limit 0 -attr name distinguishedname samaccountname dnshostname operatingsystem

REM Check: Computers with LAPS Deployed
REM Category: Computers & Servers
REM Severity: info
REM ID: COMP-004
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(ms-Mcs-AdmPwd=*))

dsquery * -filter "(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(ms-Mcs-AdmPwd=*))" -limit 0 -attr name distinguishedname samaccountname ms-mcs-admpwdexpirationtime operatingsystem

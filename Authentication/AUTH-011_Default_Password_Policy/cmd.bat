REM Check: Default Password Policy
REM Category: Authentication
REM Severity: info
REM ID: AUTH-011
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=domainDNS)

dsquery * -filter "(objectClass=domainDNS)" -limit 0 -attr name distinguishedname minpwdlength pwdhistorylength lockoutthreshold lockoutduration maxpwdage minpwdage pwdproperties

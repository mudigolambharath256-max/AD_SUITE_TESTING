REM Check: Domain Password Policy (from Domain Object)
REM Category: Group Policy
REM Severity: info
REM ID: GPO-011
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=domainDNS)

dsquery * -filter "(objectClass=domainDNS)" -limit 0 -attr name distinguishedname minpwdlength pwdhistorylength lockoutthreshold lockoutduration maxpwdage minpwdage pwdproperties

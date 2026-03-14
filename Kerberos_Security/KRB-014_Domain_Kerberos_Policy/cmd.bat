REM Check: Domain Kerberos Policy
REM Category: Kerberos Security
REM Severity: info
REM ID: KRB-014
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=domainDNS)

dsquery * -filter "(objectClass=domainDNS)" -limit 0 -attr name distinguishedname maxpwdage lockoutduration lockoutthreshold msds-supportedencryptiontypes

REM Check: Domain Functional Level
REM Category: Domain Controllers
REM Severity: info
REM ID: DC-002
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=domainDNS)

dsquery * -filter "(objectClass=domainDNS)" -limit 0 -attr name distinguishedname msds-behavior-version

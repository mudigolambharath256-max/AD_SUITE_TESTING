REM Check: Trust Partner Domains
REM Category: Trust Relationships
REM Severity: info
REM ID: TRST-013
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=trustedDomain)

dsquery * -filter "(objectClass=trustedDomain)" -limit 0 -attr name distinguishedname cn trustpartner flatname

REM Check: Trust Security Identifiers
REM Category: Trust Relationships
REM Severity: info
REM ID: TRST-015
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=trustedDomain)

dsquery * -filter "(objectClass=trustedDomain)" -limit 0 -attr name distinguishedname cn flatname securityidentifier

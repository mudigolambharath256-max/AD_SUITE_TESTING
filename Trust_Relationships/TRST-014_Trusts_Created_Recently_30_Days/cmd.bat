REM Check: Trusts Created Recently (30 Days)
REM Category: Trust Relationships
REM Severity: medium
REM ID: TRST-014
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=trustedDomain)

dsquery * -filter "(objectClass=trustedDomain)" -limit 0 -attr name distinguishedname cn flatname whencreated whenchanged

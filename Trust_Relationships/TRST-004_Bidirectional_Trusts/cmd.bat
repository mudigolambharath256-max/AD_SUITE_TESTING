REM Check: Bidirectional Trusts
REM Category: Trust Relationships
REM Severity: high
REM ID: TRST-004
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(trustDirection=3))

dsquery * -filter "(&(objectClass=trustedDomain)(trustDirection=3))" -limit 0 -attr name distinguishedname cn flatname trustdirection trustattributes

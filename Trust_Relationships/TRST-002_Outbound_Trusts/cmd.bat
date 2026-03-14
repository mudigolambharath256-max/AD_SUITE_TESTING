REM Check: Outbound Trusts
REM Category: Trust Relationships
REM Severity: medium
REM ID: TRST-002
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(trustDirection=2))

dsquery * -filter "(&(objectClass=trustedDomain)(trustDirection=2))" -limit 0 -attr name distinguishedname cn flatname trustdirection trustattributes

REM Check: Inbound Trusts
REM Category: Trust Relationships
REM Severity: low
REM ID: TRST-003
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(trustDirection=1))

dsquery * -filter "(&(objectClass=trustedDomain)(trustDirection=1))" -limit 0 -attr name distinguishedname cn flatname trustdirection trustattributes

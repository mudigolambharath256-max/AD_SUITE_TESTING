REM Check: External Trusts (Non-Forest)
REM Category: Trust Relationships
REM Severity: high
REM ID: TRST-005
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(trustType=2))

dsquery * -filter "(&(objectClass=trustedDomain)(trustType=2))" -limit 0 -attr name distinguishedname cn flatname trusttype trustattributes

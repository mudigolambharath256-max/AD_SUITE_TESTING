REM Check: Shortcut Trusts
REM Category: Trust Relationships
REM Severity: low
REM ID: TRST-017
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(trustType=2))

dsquery * -filter "(&(objectClass=trustedDomain)(trustType=2))" -limit 0 -attr name distinguishedname cn flatname trusttype

REM Check: Trust Attributes - Forest Transitive
REM Category: Trust Relationships
REM Severity: high
REM ID: TRST-026
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(trustAttributes:1.2.840.113556.1.4.803:=8))

dsquery * -filter "(&(objectClass=trustedDomain)(trustAttributes:1.2.840.113556.1.4.803:=8))" -limit 0 -attr name distinguishedname cn flatname trustattributes

REM Check: Trust Attributes - Within Forest
REM Category: Trust Relationships
REM Severity: info
REM ID: TRST-027
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(trustAttributes:1.2.840.113556.1.4.803:=32))

dsquery * -filter "(&(objectClass=trustedDomain)(trustAttributes:1.2.840.113556.1.4.803:=32))" -limit 0 -attr name distinguishedname cn flatname trustattributes

REM Check: Trusts Without SID Filtering
REM Category: Trust Relationships
REM Severity: critical
REM ID: TRST-007
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(trustAttributes:1.2.840.113556.1.4.803:=64))

dsquery * -filter "(&(objectClass=trustedDomain)(trustAttributes:1.2.840.113556.1.4.803:=64))" -limit 0 -attr name distinguishedname cn flatname trustdirection trustattributes

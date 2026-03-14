REM Check: Trusts with SID History Enabled
REM Category: Trust Relationships
REM Severity: critical
REM ID: TRST-008
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(trustAttributes:1.2.840.113556.1.4.803:=32))

dsquery * -filter "(&(objectClass=trustedDomain)(trustAttributes:1.2.840.113556.1.4.803:=32))" -limit 0 -attr name distinguishedname cn flatname trustattributes

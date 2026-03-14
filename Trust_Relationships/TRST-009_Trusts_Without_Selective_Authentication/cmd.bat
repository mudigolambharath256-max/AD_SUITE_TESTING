REM Check: Trusts Without Selective Authentication
REM Category: Trust Relationships
REM Severity: high
REM ID: TRST-009
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(trustType=2)(!(trustAttributes:1.2.840.113556.1.4.803:=16)))

dsquery * -filter "(&(objectClass=trustedDomain)(trustType=2)(!(trustAttributes:1.2.840.113556.1.4.803:=16)))" -limit 0 -attr name distinguishedname cn flatname trustattributes

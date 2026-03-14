REM Check: Parent-Child Domain Trusts
REM Category: Trust Relationships
REM Severity: info
REM ID: TRST-016
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(trustType=2)(trustAttributes:1.2.840.113556.1.4.803:=4))

dsquery * -filter "(&(objectClass=trustedDomain)(trustType=2)(trustAttributes:1.2.840.113556.1.4.803:=4))" -limit 0 -attr name distinguishedname cn flatname trusttype trustattributes

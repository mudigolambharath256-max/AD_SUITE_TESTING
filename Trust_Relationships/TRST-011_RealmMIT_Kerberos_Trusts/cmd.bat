REM Check: Realm/MIT Kerberos Trusts
REM Category: Trust Relationships
REM Severity: medium
REM ID: TRST-011
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(trustType=3))

dsquery * -filter "(&(objectClass=trustedDomain)(trustType=3))" -limit 0 -attr name distinguishedname cn flatname trusttype

REM Check: Trusts with RC4 Only
REM Category: Trust Relationships
REM Severity: high
REM ID: TRST-020
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectClass=trustedDomain)(!(msDS-SupportedEncryptionTypes:1.2.840.113556.1.4.803:=24)))

dsquery * -filter "(&(objectClass=trustedDomain)(!(msDS-SupportedEncryptionTypes:1.2.840.113556.1.4.803:=24)))" -limit 0 -attr name distinguishedname cn flatname msds-supportedencryptiontypes

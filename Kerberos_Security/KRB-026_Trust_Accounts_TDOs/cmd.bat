REM Check: Trust Accounts (TDOs)
REM Category: Kerberos Security
REM Severity: info
REM ID: KRB-026
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=trustedDomain)

dsquery * -filter "(objectClass=trustedDomain)" -limit 0 -attr name distinguishedname cn trustdirection trusttype trustattributes msds-supportedencryptiontypes

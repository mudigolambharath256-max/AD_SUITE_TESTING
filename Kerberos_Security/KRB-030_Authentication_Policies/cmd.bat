REM Check: Authentication Policies
REM Category: Kerberos Security
REM Severity: info
REM ID: KRB-030
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=msDS-AuthNPolicy)

dsquery * -filter "(objectClass=msDS-AuthNPolicy)" -limit 0 -attr name distinguishedname cn msds-userallowedtoauthenticateto

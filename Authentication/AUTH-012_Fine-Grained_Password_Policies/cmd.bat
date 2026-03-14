REM Check: Fine-Grained Password Policies
REM Category: Authentication
REM Severity: info
REM ID: AUTH-012
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=msDS-PasswordSettings)

dsquery * -filter "(objectClass=msDS-PasswordSettings)" -limit 0 -attr name distinguishedname cn msds-minimumpasswordlength msds-passwordcomplexityenabled msds-lockoutthreshold msds-passwordsettingsprecedence

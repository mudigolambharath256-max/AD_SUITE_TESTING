REM Check: Authentication Policy Silos
REM Category: Authentication
REM Severity: info
REM ID: AUTH-028
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=msDS-AuthNPolicySilo)

dsquery * -filter "(objectClass=msDS-AuthNPolicySilo)" -limit 0 -attr name distinguishedname cn msds-authnpolicysiloenforced

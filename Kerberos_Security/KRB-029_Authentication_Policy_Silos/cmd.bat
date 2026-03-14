REM Check: Authentication Policy Silos
REM Category: Kerberos Security
REM Severity: info
REM ID: KRB-029
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=msDS-AuthNPolicySilo)

dsquery * -filter "(objectClass=msDS-AuthNPolicySilo)" -limit 0 -attr name distinguishedname cn msds-authnpolicysiloenforced

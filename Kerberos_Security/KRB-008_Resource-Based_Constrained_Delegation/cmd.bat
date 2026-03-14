REM Check: Resource-Based Constrained Delegation
REM Category: Kerberos Security
REM Severity: high
REM ID: KRB-008
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToActOnBehalfOfOtherIdentity=*))

dsquery * -filter "(&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-AllowedToActOnBehalfOfOtherIdentity=*))" -limit 0 -attr name distinguishedname samaccountname objectclass msds-allowedtoactonbehalfofotheridentity

REM Check: Cross-Domain Group Memberships
REM Category: Trust Relationships
REM Severity: info
REM ID: TRST-023
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(member=*CN=ForeignSecurityPrincipals*))

dsquery * -filter "(&(objectCategory=group)(member=*CN=ForeignSecurityPrincipals*))" -limit 0 -attr name distinguishedname cn member

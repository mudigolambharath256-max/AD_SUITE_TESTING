REM Check: Azure AD Provisioning Groups
REM Category: Azure AD Integration
REM Severity: info
REM ID: AAD-012
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(|(cn=*Azure*)(cn=*AAD*)(cn=*O365*)(cn=*M365*)))

dsquery * -filter "(&(objectCategory=group)(|(cn=*Azure*)(cn=*AAD*)(cn=*O365*)(cn=*M365*)))" -limit 0 -attr name distinguishedname cn member description

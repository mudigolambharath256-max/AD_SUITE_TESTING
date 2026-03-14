REM Check: Directory Sync Status Container
REM Category: Azure AD Integration
REM Severity: info
REM ID: AAD-023
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=msDS-DeviceRegistrationService)

dsquery * -filter "(objectClass=msDS-DeviceRegistrationService)" -limit 0 -attr name distinguishedname cn

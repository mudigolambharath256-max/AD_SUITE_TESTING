REM Check: Hybrid Azure AD Joined Devices
REM Category: Azure AD Integration
REM Severity: info
REM ID: AAD-024
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=computer)(msDS-DeviceID=*))

dsquery * -filter "(&(objectCategory=computer)(msDS-DeviceID=*))" -limit 0 -attr name distinguishedname samaccountname msds-deviceid operatingsystem

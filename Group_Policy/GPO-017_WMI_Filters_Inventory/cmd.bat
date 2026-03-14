REM Check: WMI Filters Inventory
REM Category: Group Policy
REM Severity: info
REM ID: GPO-017
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=msWMI-Som)

dsquery * -filter "(objectClass=msWMI-Som)" -limit 0 -attr name distinguishedname mswmi-name mswmi-author mswmi-parm2

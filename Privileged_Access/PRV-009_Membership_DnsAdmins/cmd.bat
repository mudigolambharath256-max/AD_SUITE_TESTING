REM Check: Membership: DnsAdmins
REM Category: Privileged Access
REM Severity: critical
REM ID: PRV-009
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (&(objectCategory=group)(cn=DnsAdmins))

dsquery * -filter "(&(objectCategory=group)(cn=DnsAdmins))" -limit 0 -attr name distinguishedname cn member

REM Check: Certificate Templates Version
REM Category: Certificate Services
REM Severity: info
REM ID: CERT-030
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=pKICertificateTemplate)

dsquery * -filter "(objectClass=pKICertificateTemplate)" -limit 0 -attr name distinguishedname cn displayname mspki-template-schema-version mspki-template-minor-revision

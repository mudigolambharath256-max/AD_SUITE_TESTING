REM Check: Certificate Template Inventory
REM Category: Certificate Services
REM Severity: info
REM ID: CERT-001
REM Requirements: dsquery (RSAT DS tools)
REM ============================================

@echo off
REM LDAP search (CMD + dsquery)
REM Filter: (objectClass=pKICertificateTemplate)

dsquery * -filter "(objectClass=pKICertificateTemplate)" -limit 0 -attr name distinguishedname cn displayname pkiextendedkeyusage mspki-enrollment-flag mspki-certificate-name-flag mspki-ra-signature

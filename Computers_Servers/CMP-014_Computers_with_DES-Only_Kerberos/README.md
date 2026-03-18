# Computers with DES-Only Kerberos

## Description
Finds computers configured for DES-only Kerberos (weak encryption).

## Severity
CRITICAL

## Category
Computers & Servers

## Remediation
Remove DES-only restriction and update msDS-SupportedEncryptionTypes to prefer AES.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1558.003



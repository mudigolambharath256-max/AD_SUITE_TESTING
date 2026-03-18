# Computers Missing Encryption Types

## Description
Finds computers without explicit msDS-SupportedEncryptionTypes (defaults to RC4).

## Severity
MEDIUM

## Category
Computers & Servers

## Remediation
Set msDS-SupportedEncryptionTypes to enable AES and disable weak encryption.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1558.003



# Accounts Without Explicit Encryption Types

## Description
Finds accounts without msDS-SupportedEncryptionTypes set (defaults to RC4).

## Severity
MEDIUM

## Category
Kerberos Security

## Remediation
Set msDS-SupportedEncryptionTypes to enable AES encryption.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/security/kerberos/kerberos-authentication-overview

## MITRE ATT&CK
T1558.003



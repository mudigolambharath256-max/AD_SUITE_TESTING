# DES-Only Kerberos (Users)

## Description
Finds users with USE_DES_KEY_ONLY set (weak encryption).

## Severity
CRITICAL

## Category
Kerberos Security

## Remediation
Disable DES. Set msDS-SupportedEncryptionTypes to AES-only.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/security/kerberos/kerberos-authentication-overview

## MITRE ATT&CK
T1558.003



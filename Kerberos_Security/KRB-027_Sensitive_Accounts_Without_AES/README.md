# Sensitive Accounts Without AES

## Description
Finds admin accounts not supporting AES encryption.

## Severity
HIGH

## Category
Kerberos Security

## Remediation
Set msDS-SupportedEncryptionTypes to include AES for admin accounts.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/security/kerberos/kerberos-authentication-overview

## MITRE ATT&CK
T1558.003



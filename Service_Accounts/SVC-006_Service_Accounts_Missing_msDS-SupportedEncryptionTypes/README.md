# Service Accounts Missing msDS-SupportedEncryptionTypes

## Description
Lists SPN accounts without msDS-SupportedEncryptionTypes explicitly set (often implies RC4 allowed).

## Severity
MEDIUM

## Category
Service Accounts

## Remediation
Explicitly set encryption types to AES where possible and rotate passwords.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/service-accounts/service-accounts

## MITRE ATT&CK
T1558.003



# Service Accounts with Reversible Encryption Allowed

## Description
Finds SPN accounts with ENCRYPTED_TEXT_PASSWORD_ALLOWED set.

## Severity
CRITICAL

## Category
Service Accounts

## Remediation
Disable reversible encryption and rotate passwords. Remove legacy dependencies.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/service-accounts/service-accounts

## MITRE ATT&CK
T1003



# Service Accounts with DES Only

## Description
Finds SPN accounts with USE_DES_KEY_ONLY set (weak crypto).

## Severity
CRITICAL

## Category
Service Accounts

## Remediation
Disable DES. Prefer AES-only Kerberos and rotate credentials/tickets after changes.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/service-accounts/service-accounts

## MITRE ATT&CK
T1558.003



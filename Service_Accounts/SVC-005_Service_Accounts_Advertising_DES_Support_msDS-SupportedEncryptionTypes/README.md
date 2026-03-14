# Service Accounts Advertising DES Support (msDS-SupportedEncryptionTypes)

## Description
Finds SPN accounts with DES bits enabled in msDS-SupportedEncryptionTypes.

## Severity
CRITICAL

## Category
Service Accounts

## Remediation
Remove DES support and move to AES. Validate service compatibility.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/service-accounts/service-accounts

## MITRE ATT&CK
T1558.003



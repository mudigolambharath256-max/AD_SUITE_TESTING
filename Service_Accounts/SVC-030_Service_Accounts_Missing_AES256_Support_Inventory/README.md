# Service Accounts Missing AES256 Support (Inventory)

## Description
Lists SPN accounts not advertising AES256 support.

## Severity
MEDIUM

## Category
Service Accounts

## Remediation
Where supported, enable AES-only and rotate passwords/tickets after making changes.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/service-accounts/service-accounts

## MITRE ATT&CK
T1558.003



# Service Accounts with “Password Not Required”

## Description
Finds SPN accounts with PASSWD_NOTREQD set.

## Severity
CRITICAL

## Category
Service Accounts

## Remediation
Unset PASSWD_NOTREQD and rotate the credential immediately.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/service-accounts/service-accounts

## MITRE ATT&CK
T1110



# Service Accounts with Kerberos Pre-Auth Disabled

## Description
Finds SPN accounts with DONT_REQ_PREAUTH set (AS-REP roasting).

## Severity
CRITICAL

## Category
Service Accounts

## Remediation
Enable Kerberos pre-auth for service accounts. Rotate passwords after changes.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/service-accounts/service-accounts

## MITRE ATT&CK
T1558.004



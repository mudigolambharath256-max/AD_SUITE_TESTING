# Accounts That Had Admin Rights in Past

## Description
Finds accounts with adminCount=1 but not in admin groups (orphaned admin rights).

## Severity
HIGH

## Category
Users & Accounts

## Remediation
Clear adminCount and reset ACL if user is no longer admin. Run AdminSDHolder cleanup.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1078.002



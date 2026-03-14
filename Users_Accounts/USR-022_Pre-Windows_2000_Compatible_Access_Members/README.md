# Pre-Windows 2000 Compatible Access Members

## Description
Lists members of Pre-Windows 2000 Compatible Access group (exposes anonymous access).

## Severity
HIGH

## Category
Users & Accounts

## Remediation
Remove "Anonymous Logon" and "Everyone" from this group. Modern AD does not require these.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1087.002



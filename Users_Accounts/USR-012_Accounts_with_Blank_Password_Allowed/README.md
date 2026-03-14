# Accounts with Blank Password Allowed

## Description
Finds accounts with PASSWD_NOTREQD flag - can have blank password.

## Severity
CRITICAL

## Category
Users & Accounts

## Remediation
Remove PASSWD_NOTREQD flag and set a strong password. Run: Set-ADUser -Identity <user> -PasswordNotRequired $false

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1110.001



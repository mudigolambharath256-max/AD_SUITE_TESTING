# Accounts with Reversible Password Encryption

## Description
Finds accounts with ENCRYPTED_TEXT_PASSWORD_ALLOWED flag (password stored reversibly).

## Severity
CRITICAL

## Category
Users & Accounts

## Remediation
Remove reversible encryption flag and reset password. Only required for CHAP/Digest auth.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1003



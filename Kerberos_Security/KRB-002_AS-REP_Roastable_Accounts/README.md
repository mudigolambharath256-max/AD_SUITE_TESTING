# AS-REP Roastable Accounts

## Description
Finds accounts with "Do not require Kerberos preauthentication" enabled.

## Severity
CRITICAL

## Category
Kerberos Security

## Remediation
Enable Kerberos pre-authentication. Run: Set-ADUser -DoesNotRequirePreAuth $false

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/security/kerberos/kerberos-authentication-overview

## MITRE ATT&CK
T1558.004



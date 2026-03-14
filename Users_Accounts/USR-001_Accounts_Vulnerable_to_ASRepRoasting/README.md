# Accounts Vulnerable to ASRepRoasting

## Description
Finds accounts with "Do not require Kerberos preauthentication" enabled. Attackers can request AS-REP and crack the hash offline.

## Severity
CRITICAL

## Category
Users & Accounts

## Remediation
Enable Kerberos pre-authentication for all accounts. Run: Set-ADUser -Identity <user> -DoesNotRequirePreAuth $false

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1558.004



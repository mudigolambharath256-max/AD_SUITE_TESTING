# Computers Trusted as DCs (Not Actual DCs)

## Description
Finds computers with SERVER_TRUST_ACCOUNT but not in DC group.

## Severity
CRITICAL

## Category
Computers & Servers

## Remediation
Investigate why non-DC has SERVER_TRUST_ACCOUNT flag. May indicate rogue DC.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1207



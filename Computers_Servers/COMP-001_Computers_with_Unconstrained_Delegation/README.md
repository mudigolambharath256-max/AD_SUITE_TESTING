# Computers with Unconstrained Delegation

## Description
Finds computers trusted for delegation (can impersonate any user). Excludes DCs which have this by default.

## Severity
CRITICAL

## Category
Computers & Servers

## Remediation
Remove unconstrained delegation. Migrate to constrained delegation or RBCD.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/active-directory-security-assessment

## MITRE ATT&CK
T1558
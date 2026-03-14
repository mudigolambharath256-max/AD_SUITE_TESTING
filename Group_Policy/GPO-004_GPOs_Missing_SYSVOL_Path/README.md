# GPOs Missing SYSVOL Path

## Description
Finds GPOs without gPCFileSysPath (broken SYSVOL linkage).

## Severity
HIGH

## Category
Group Policy

## Remediation
Repair SYSVOL replication. Investigate broken GPO.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/group-policy/group-policy-overview

## MITRE ATT&CK
T1484.001



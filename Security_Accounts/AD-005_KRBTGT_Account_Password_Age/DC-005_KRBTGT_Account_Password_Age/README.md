# KRBTGT Account Password Age

## Description
Checks the krbtgt account password age. Should be changed at least every 180 days.

## Severity
HIGH

## Category
Domain Controllers

## Remediation
Reset krbtgt password twice (with replication interval between). Do this at least every 180 days.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview

## MITRE ATT&CK
T1558.001



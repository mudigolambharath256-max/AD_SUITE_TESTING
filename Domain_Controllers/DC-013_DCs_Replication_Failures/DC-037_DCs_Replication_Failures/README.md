# DCs Replication Failures

## Description
Identifies Domain Controllers with replication failures or delays. Replication issues can lead to inconsistent AD data and authentication problems.

## Severity
HIGH

## Category
Domain Controllers

## Remediation
Investigate replication errors using repadmin /showrepl. Check network connectivity, DNS resolution, and firewall rules between DCs. Resolve any lingering objects.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview




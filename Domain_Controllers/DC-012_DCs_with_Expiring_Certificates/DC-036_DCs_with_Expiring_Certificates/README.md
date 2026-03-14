# DCs with Expiring Certificates

## Description
Identifies Domain Controllers with certificates expiring within 90 days. Expired DC certificates can break LDAPS, Kerberos, and replication.

## Severity
HIGH

## Category
Domain Controllers

## Remediation
Monitor DC certificate expiration dates. Renew certificates before expiration. Ensure auto-enrollment is configured for DC certificates.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview




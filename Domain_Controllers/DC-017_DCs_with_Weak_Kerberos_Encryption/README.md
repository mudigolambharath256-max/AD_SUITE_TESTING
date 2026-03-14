# DCs with Weak Kerberos Encryption

## Description
Identifies Domain Controllers configured to support weak Kerberos encryption types (DES, RC4). Modern DCs should only support AES128 and AES256.

## Severity
HIGH

## Category
Domain Controllers

## Remediation
Configure Group Policy to disable DES and RC4 encryption types. Set "Network security: Configure encryption types allowed for Kerberos" to only AES128_HMAC_SHA1 and AES256_HMAC_SHA1.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview

## MITRE ATT&CK
T1558.003




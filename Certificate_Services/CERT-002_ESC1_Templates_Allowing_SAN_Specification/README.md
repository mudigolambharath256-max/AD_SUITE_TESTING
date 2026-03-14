# ESC1: Templates Allowing SAN Specification

## Description
Finds templates where enrollee can specify Subject Alternative Name (ESC1 vulnerability).

## Severity
CRITICAL

## Category
Certificate Services

## Remediation
Remove ENROLLEE_SUPPLIES_SUBJECT flag or restrict enrollment to trusted groups with manager approval.

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://posts.specterops.io/certified-pre-owned-d95910965cd2
- https://learn.microsoft.com/en-us/windows-server/identity/ad-cs/

## MITRE ATT&CK
T1649



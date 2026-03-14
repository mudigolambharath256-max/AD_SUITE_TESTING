# ESC6: CA Allowing SAN in Requests

## Description
Lists CAs to check for EDITF_ATTRIBUTESUBJECTALTNAME2 flag (requires manual CA check).

## Severity
HIGH

## Category
Certificate Services

## Remediation
Disable SAN specification in CA settings: certutil -setreg policy\EditFlags -EDITF_ATTRIBUTESUBJECTALTNAME2

## References
- https://attack.mitre.org/
- https://learn.microsoft.com/en-us/windows-server/identity/active-directory-domain-services
- https://posts.specterops.io/certified-pre-owned-d95910965cd2
- https://learn.microsoft.com/en-us/windows-server/identity/ad-cs/

## MITRE ATT&CK
T1649



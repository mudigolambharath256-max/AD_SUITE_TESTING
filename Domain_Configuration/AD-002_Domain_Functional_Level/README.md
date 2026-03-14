# AD-002 — Domain Functional Level

## Purpose
Checks the domain functional level to ensure it supports modern security features like Authentication Policies, fine-grained password policies, and advanced Kerberos armoring.

## Attack Scenario
Domains running at lower functional levels lack critical security features that prevent modern attacks. For example, functional levels below Windows Server 2016 cannot use Authentication Policy Silos to protect privileged accounts from credential theft.

## LDAP Details
| Field        | Value                          |
|--------------|-------------------------------|
| Filter       | `(objectClass=domainDNS)`      |
| Search Base  | `<DomainDN>` (Base scope)      |
| Partition    | Default NC                     |
| Object Class | `domainDNS`                    |
| Scope        | Base                           |

## Attributes Returned
- `msDS-Behavior-Version` — Numeric functional level value
- `distinguishedName` — Domain DN
- `name` — Domain name

## Execution
```powershell
# PowerShell (AD Module)
.\powershell.ps1

# ADSI (no module required)
.\adsi.ps1

# Combined (auto-detects best engine)
.\combined_multiengine.ps1
```

## Expected Output
Domains with functional level below Windows Server 2016 (level 7) are flagged as HIGH severity findings.

## Remediation
1. Upgrade all domain controllers to Windows Server 2016 or later
2. Raise domain functional level using Active Directory Domains and Trusts
3. Verify all applications support the new functional level before upgrading

## References
- [Domain and Forest Functional Levels](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/active-directory-functional-levels)
- MITRE ATT&CK: T1484 (Domain Policy Modification)
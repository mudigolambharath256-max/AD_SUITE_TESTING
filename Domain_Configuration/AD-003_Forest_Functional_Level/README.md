# AD-003 — Forest Functional Level

## Purpose
Checks the forest functional level to ensure it supports modern security features like cross-forest trusts, advanced replication, and forest-wide security policies.

## Attack Scenario
Forests running at lower functional levels lack critical security features and may be vulnerable to attacks that exploit legacy authentication methods or weak trust configurations.

## LDAP Details
| Field        | Value                          |
|--------------|-------------------------------|
| Filter       | `(objectClass=crossRefContainer)` |
| Search Base  | `CN=Partitions,CN=Configuration,<ForestDN>` |
| Partition    | Configuration NC               |
| Object Class | `crossRefContainer`            |
| Scope        | Base                           |

## Attributes Returned
- `msDS-Behavior-Version` — Numeric functional level value
- `distinguishedName` — Partitions container DN

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
Forests with functional level below Windows Server 2016 (level 7) are flagged as HIGH severity findings.

## Remediation
1. Upgrade all domain controllers in all domains to Windows Server 2016 or later
2. Raise domain functional levels for all domains first
3. Raise forest functional level using Active Directory Domains and Trusts
4. Verify all cross-forest applications support the new functional level

## References
- [Domain and Forest Functional Levels](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/active-directory-functional-levels)
- MITRE ATT&CK: T1484 (Domain Policy Modification)
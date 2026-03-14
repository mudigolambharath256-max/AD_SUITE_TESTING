# Trust Management Checks

This folder contains checks related to Active Directory trust relationships and foreign security principals.

## Overview

Trust relationships extend authentication boundaries between domains and forests. These checks help identify trust configurations and potential security issues related to cross-domain access.

## Checks in This Category

### Trust Configuration (2 checks)
- **AD-016**: Trust Relationships - Inventory of all domain trusts
- **AD-017**: Trusts Without SID Filtering - Trusts with disabled SID filtering

### Foreign Security Principals (1 check)
- **AD-031**: Orphaned Foreign Security Principals - FSPs from deleted trusts

## Severity Distribution

- **HIGH**: 1 check (AD-017)
- **INFO**: 2 checks

## Usage

Each check folder contains 5 implementation variants:
1. **powershell.ps1** - ActiveDirectory module (requires RSAT)
2. **adsi.ps1** - Native ADSI (no dependencies)
3. **csharp.cs** - Standalone C# code
4. **cmd.bat** - Windows batch with dsquery
5. **combined_multiengine.ps1** - Multi-engine orchestrator

## Quick Start

```powershell
# List all trust relationships
.\AD-016_Trust_Relationships\AD-016_Trust_Relationships\powershell.ps1

# Check for trusts without SID filtering (security risk)
.\AD-017_Trusts_Without_SID_Filtering\AD-017_Trusts_Without_SID_Filtering\powershell.ps1

# Find orphaned FSPs
.\AD-031_Orphaned_Foreign_Security_Principals\AD-031_Orphaned_Foreign_Security_Principals\powershell.ps1
```

## Trust Relationships Overview

### Trust Types
- **Parent-Child**: Automatic two-way transitive trusts
- **Tree-Root**: Between domain trees in same forest
- **External**: Non-transitive trust with external domain
- **Forest**: Transitive trust between forests
- **Realm**: Trust with Kerberos realm (non-Windows)
- **Shortcut**: Optimization trust within forest

### Trust Directions
- **Inbound**: External domain trusts this domain
- **Outbound**: This domain trusts external domain
- **Bidirectional**: Two-way trust

## Security Considerations

### SID Filtering (AD-017)
⚠️ **HIGH SEVERITY**: Trusts without SID filtering are vulnerable to privilege escalation

**What is SID Filtering?**
- Security boundary that filters SIDs from trusted domains
- Prevents SID history injection attacks
- Blocks privileged SIDs from crossing trust boundaries

**When Disabled**:
- Attackers can inject privileged SIDs (e.g., Domain Admins)
- Enables cross-domain privilege escalation
- Compromises trust security model

**Best Practices**:
- Enable SID filtering on all external trusts
- Only disable for migration scenarios (temporary)
- Document exceptions with business justification
- Re-enable immediately after migration

### Foreign Security Principals (AD-031)

**What are FSPs?**
- Placeholder objects for principals from trusted domains
- Created when external principals are added to local groups
- Stored in `CN=ForeignSecurityPrincipals` container

**Orphaned FSPs**:
- FSPs referencing deleted trusts or non-existent SIDs
- Indicate stale trust relationships
- Can cause access issues or confusion

**Cleanup Recommendations**:
- Identify orphaned FSPs with AD-031
- Verify trust status before removal
- Remove FSPs from deleted trusts
- Document cleanup actions

## Trust Inventory (AD-016)

**Information Collected**:
- Trust name and target domain
- Trust type and direction
- Trust attributes (transitive, forest-wide, etc.)
- Creation date

**Use Cases**:
- Trust relationship documentation
- Security boundary mapping
- Compliance auditing
- Trust relationship review

## MITRE ATT&CK Mappings

- **T1482** (Domain Trust Discovery): AD-016

## Security Recommendations

### Trust Security Checklist
1. ✅ Document all trusts (AD-016)
2. ✅ Enable SID filtering on external trusts (AD-017)
3. ✅ Remove orphaned FSPs (AD-031)
4. ✅ Regularly review trust necessity
5. ✅ Implement least privilege across trusts
6. ✅ Monitor cross-trust authentication

### Trust Review Process
1. Run AD-016 to inventory all trusts
2. Verify business justification for each trust
3. Check SID filtering status with AD-017
4. Identify and clean orphaned FSPs with AD-031
5. Document trust purpose and owners
6. Schedule regular trust reviews (quarterly)

## Related Categories

- **Domain_Configuration** - Domain-wide settings
- **Domain_Controllers** - DC security checks
- **Security_Accounts** - Account security

## Total Checks: 3

# Domain Configuration Checks

This folder contains checks for domain-wide and forest-wide configuration settings that affect the entire Active Directory environment.

## Overview

These checks assess domain and forest functional levels, security policies, and configuration settings that apply across the entire AD environment rather than to specific objects.

## Checks in This Category

### Functional Levels (2 checks)
- **AD-002**: Domain Functional Level - Current domain functional level
- **AD-003**: Forest Functional Level - Current forest functional level

### Kerberos & Authentication (1 check)
- **AD-006**: Kerberos Encryption Types (Domain) - Supported Kerberos encryption at domain level

### Password Policies (1 check)
- **AD-019**: Default Domain Password Policy - Default password policy settings

### Security Settings (2 checks)
- **AD-018**: ms-DS-MachineAccountQuota Setting - Computer join quota (should be 0)
- **AD-026**: Anonymous LDAP Access - Anonymous LDAP bind configuration

### Forest Features (2 checks)
- **AD-013**: Recycle Bin Enabled Check - AD Recycle Bin status
- **AD-025**: Tombstone Lifetime - Deleted object retention period

## Severity Distribution

- **HIGH**: 2 checks (AD-018, AD-026)
- **INFO**: 6 checks

## Usage

Each check folder contains 5 implementation variants:
1. **powershell.ps1** - ActiveDirectory module (requires RSAT)
2. **adsi.ps1** - Native ADSI (no dependencies)
3. **csharp.cs** - Standalone C# code
4. **cmd.bat** - Windows batch with dsquery
5. **combined_multiengine.ps1** - Multi-engine orchestrator

## Quick Start

```powershell
# Check domain functional level
.\AD-002_Domain_Functional_Level\AD-002_Domain_Functional_Level\powershell.ps1

# Check MachineAccountQuota (security critical)
.\AD-018_ms-DS-MachineAccountQuota_Setting\AD-018_ms-DS-MachineAccountQuota_Setting\powershell.ps1
```

## Security Recommendations

### High Priority
- **AD-018**: Set MachineAccountQuota to 0 to prevent unauthorized computer joins
- **AD-026**: Disable anonymous LDAP access to prevent information disclosure

### Best Practices
- **AD-002/AD-003**: Upgrade to latest functional levels for security features
- **AD-013**: Enable AD Recycle Bin for accidental deletion recovery
- **AD-019**: Enforce strong password policies (length ≥14, complexity enabled)

## MITRE ATT&CK Mappings

- **T1136.002** (Create Account - Domain Account): AD-018

## Related Categories

- **Domain_Controllers** - DC-specific checks
- **Security_Accounts** - Account-related security checks
- **Trust_Management** - Trust relationships

## Total Checks: 8

# Computer Management Checks

This folder contains checks related to computer objects in Active Directory, focusing on LAPS (Local Administrator Password Solution) and BitLocker key storage.

## Overview

These checks help assess the deployment and coverage of LAPS and BitLocker across domain-joined computers, which are critical for endpoint security management.

## Checks in This Category

### LAPS Schema & Deployment (4 checks)
- **AD-007**: LAPS Schema Extended - Legacy LAPS schema check
- **AD-008**: Windows LAPS Schema Extended - Windows LAPS (2023+) schema check
- **AD-009**: Computers Without LAPS Password - Enabled computers missing LAPS
- **AD-010**: Computers with LAPS Inventory - LAPS coverage tracking

### BitLocker Recovery (1 check)
- **AD-011**: Computers with BitLocker Keys Stored - BitLocker recovery keys in AD

## Severity Distribution

- **HIGH**: 1 check (AD-009)
- **INFO**: 4 checks

## Usage

Each check folder contains 5 implementation variants:
1. **powershell.ps1** - ActiveDirectory module (requires RSAT)
2. **adsi.ps1** - Native ADSI (no dependencies)
3. **csharp.cs** - Standalone C# code
4. **cmd.bat** - Windows batch with dsquery
5. **combined_multiengine.ps1** - Multi-engine orchestrator

## Quick Start

```powershell
# Check LAPS schema extension
.\AD-007_LAPS_Schema_Extended\AD-007_LAPS_Schema_Extended\powershell.ps1

# Find computers without LAPS (security gap)
.\AD-009_Computers_Without_LAPS_Password\AD-009_Computers_Without_LAPS_Password\powershell.ps1

# Check BitLocker key storage
.\AD-011_Computers_with_BitLocker_Keys_Stored\AD-011_Computers_with_BitLocker_Keys_Stored\powershell.ps1
```

## LAPS Overview

### Legacy LAPS vs Windows LAPS

**Legacy LAPS (AD-007)**:
- Microsoft LAPS (pre-2023)
- Schema attributes: `ms-Mcs-AdmPwd`, `ms-Mcs-AdmPwdExpirationTime`
- Requires separate installation
- Still widely deployed

**Windows LAPS (AD-008)**:
- Built into Windows Server 2025 and Windows 11 22H2+
- Schema attributes: `msLAPS-Password`, `msLAPS-PasswordExpirationTime`
- Native Windows feature
- Enhanced security features

### LAPS Deployment Checks

**AD-009: Computers Without LAPS** (HIGH severity)
- Identifies enabled computers missing LAPS passwords
- Security gap: Local admin passwords may be weak/shared
- Prioritize deployment to these systems

**AD-010: LAPS Inventory**
- Tracks LAPS coverage across environment
- Helps measure deployment progress
- Identifies LAPS version distribution

## BitLocker Recovery Keys

**AD-011: Computers with BitLocker Keys**
- Verifies BitLocker recovery key storage in AD
- Critical for disaster recovery
- Ensures encrypted drives can be recovered

**Best Practices**:
- Enable BitLocker recovery key backup to AD via GPO
- Restrict access to recovery keys (sensitive data)
- Regularly audit key storage coverage
- Document recovery procedures

## Security Recommendations

### LAPS Deployment
1. **Extend Schema**: Run AD-007 or AD-008 to verify schema readiness
2. **Deploy LAPS**: Use GPO to deploy LAPS to all workstations/servers
3. **Monitor Coverage**: Run AD-009 regularly to identify gaps
4. **Track Progress**: Use AD-010 for deployment metrics

### BitLocker Management
1. **Enable Backup**: Configure GPO to store recovery keys in AD
2. **Verify Coverage**: Run AD-011 to check key storage
3. **Secure Access**: Restrict who can read recovery keys
4. **Test Recovery**: Periodically test recovery procedures

## Performance Notes

- **AD-009**: Can be slow in large environments (filters enabled computers)
- **AD-010**: Faster (only queries computers with LAPS attributes)
- **AD-011**: Queries `msFVE-RecoveryInformation` child objects (can be slow)

## Related Categories

- **Domain_Controllers** - DC-specific security checks
- **Domain_Configuration** - Domain-wide policies
- **Security_Accounts** - Account security checks

## Total Checks: 5

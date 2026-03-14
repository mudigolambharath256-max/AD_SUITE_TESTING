# Security Accounts Checks

This folder contains checks for security-sensitive accounts and password policies in Active Directory.

## Overview

These checks focus on critical security accounts like KRBTGT and fine-grained password policies that affect authentication security across the domain.

## Checks in This Category

### Critical Accounts (1 check)
- **AD-005**: KRBTGT Account Password Age - Password age check (should be <180 days)

### Password Policies (1 check)
- **AD-012**: Password Settings Objects (Fine-Grained) - PSO inventory and configuration

## Severity Distribution

- **HIGH**: 1 check (AD-005)
- **INFO**: 1 check (AD-012)

## Usage

Each check folder contains 5 implementation variants:
1. **powershell.ps1** - ActiveDirectory module (requires RSAT)
2. **adsi.ps1** - Native ADSI (no dependencies)
3. **csharp.cs** - Standalone C# code
4. **cmd.bat** - Windows batch with dsquery
5. **combined_multiengine.ps1** - Multi-engine orchestrator

## Quick Start

```powershell
# Check KRBTGT password age (CRITICAL)
.\AD-005_KRBTGT_Account_Password_Age\AD-005_KRBTGT_Account_Password_Age\powershell.ps1

# List all Password Settings Objects
.\AD-012_Password_Settings_Objects_Fine-Grained\AD-012_Password_Settings_Objects_Fine-Grained\powershell.ps1
```

## Security Recommendations

### KRBTGT Account (AD-005)
⚠️ **CRITICAL**: The KRBTGT account password should be rotated regularly

**Best Practices**:
- Rotate KRBTGT password every 180 days (maximum)
- Use Microsoft's script for safe rotation (requires two rotations)
- Schedule rotations during maintenance windows
- Document rotation procedures

**Attack Context**:
- Compromised KRBTGT enables Golden Ticket attacks
- Attackers can forge Kerberos tickets with unlimited validity
- Persistence mechanism that survives password resets

### Password Settings Objects (AD-012)
**Best Practices**:
- Use PSOs for privileged accounts (stricter policies)
- Document PSO assignments and precedence
- Ensure PSOs don't weaken default policy
- Review PSO configurations regularly

## MITRE ATT&CK Mappings

- **T1558.001** (Kerberos Golden Ticket): AD-005

## Related Categories

- **Domain_Configuration** - Domain-wide password policies
- **Domain_Controllers** - DC security checks
- **Computer_Management** - Computer account management

## Total Checks: 2

# Domain Controllers Security Checks

This folder contains security checks specifically targeting Domain Controller objects and configurations.

## Overview

Domain Controllers are the most critical infrastructure components in Active Directory environments. These checks help identify security misconfigurations, outdated systems, and potential vulnerabilities on DC objects.

## Check Categories

### Inventory & Configuration (4 checks)
- **DC-001**: Domain Controllers Inventory - Complete DC inventory with OS and site info
- **DC-028**: RODC Inventory - Read-Only Domain Controllers
- **DC-029**: FSMO Role Holders - Domain-level FSMO role assignments
- **DC-030**: Schema Master - Forest-level Schema Master identification

### Operating System & Updates (2 checks)
- **DC-004**: DCs Running Outdated OS - Identifies DCs on Server 2012 or earlier
- **DC-046**: DCs Missing Critical Security Updates - Uninstalled critical/important updates

### SYSVOL Replication (2 checks)
- **DC-022**: DFSR SYSVOL Migration Status - DFSR configuration check
- **DC-023**: FRS SYSVOL (Deprecated) - Legacy FRS detection

### Network Security (3 checks)
- **DC-033**: DCs with SMB Signing Disabled - SMB signing enforcement check
- **DC-034**: DCs LDAP Signing Not Required - LDAP signing requirements
- **DC-035**: DCs LDAP Channel Binding Disabled - LDAP channel binding configuration

### Authentication & Encryption (2 checks)
- **DC-041**: DCs with Weak Kerberos Encryption - DES/RC4 encryption detection
- **DC-042**: DCs with Unsigned LDAP Binds Allowed - LDAP signing policy

### Certificate Management (1 check)
- **DC-036**: DCs with Expiring Certificates - Certificates expiring within 90 days

### Replication & Infrastructure (1 check)
- **DC-037**: DCs Replication Failures - AD replication health

### Access Control (3 checks)
- **DC-020**: DCs with Constrained Delegation - Delegation configuration on DC objects
- **DC-038**: DCs Null Session Enabled - Anonymous null session vulnerabilities
- **DC-040**: DC Accounts Not Protected - DC account protection status

### Service Hardening (6 checks)
- **DC-039**: DCs with Print Spooler Running - PrintNightmare vulnerability
- **DC-045**: DCs with Local Admin Accounts - Unauthorized local administrators
- **DC-048**: DCs with RDP Enabled - Remote Desktop Protocol status
- **DC-050**: DCs with Disabled Windows Firewall - Firewall profile status
- **DC-056**: DCs with PowerShell v2 Enabled - Legacy PowerShell detection
- **DC-059**: DCs with Anonymous SID Translation Enabled - Anonymous SID enumeration

### Audit & Logging (2 checks)
- **DC-047**: DCs with Weak Audit Policy - Audit policy configuration
- **DC-054**: DCs with Disabled Security Event Log - Security log status

### Password Security (1 check)
- **DC-052**: DCs with Old DSRM Password - Directory Services Restore Mode password age

## Severity Distribution

- **CRITICAL**: 2 checks (DC-038, DC-039)
- **HIGH**: 15 checks
- **MEDIUM**: 5 checks
- **INFO**: 5 checks

## Usage

Each check folder contains 5 implementation variants:
1. **powershell.ps1** - ActiveDirectory module (requires RSAT)
2. **adsi.ps1** - Native ADSI (no dependencies)
3. **csharp.cs** - Standalone C# code
4. **cmd.bat** - Windows batch with dsquery
5. **combined_multiengine.ps1** - Multi-engine orchestrator with fallback

## Quick Start

```powershell
# Run a single check (PowerShell)
.\DC-039_DCs_with_Print_Spooler_Running\DC-039_DCs_with_Print_Spooler_Running\powershell.ps1

# Run with ADSI (no RSAT required)
.\DC-039_DCs_with_Print_Spooler_Running\DC-039_DCs_with_Print_Spooler_Running\adsi.ps1

# Run with all engines and fallback
.\DC-039_DCs_with_Print_Spooler_Running\DC-039_DCs_with_Print_Spooler_Running\combined_multiengine.ps1
```

## Related Categories

- **Domain_Configuration** - Domain-wide settings and policies
- **Security_Accounts** - Security-sensitive account checks
- **Infrastructure** - AD topology and structure
- **Trust_Management** - Trust relationships and FSPs

## Security Notes

⚠️ **Critical Checks**: Prioritize DC-038 (Null Session) and DC-039 (Print Spooler)

🔒 **Hardening Focus**: Checks DC-033 through DC-059 focus on DC hardening best practices

📊 **Compliance**: Many checks align with CIS Benchmarks and Microsoft security baselines

## MITRE ATT&CK Mappings

- **T1557.001** (LLMNR/NBT-NS Poisoning): DC-033, DC-034, DC-035
- **T1087.002** (Domain Account Discovery): DC-038
- **T1068** (Privilege Escalation): DC-039
- **T1078.002** (Domain Accounts): DC-040

## Total Checks: 27

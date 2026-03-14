# DCs LDAP Channel Binding Disabled

## Description
This check identifies Domain Controllers that do not enforce LDAP channel binding, making them vulnerable to LDAP relay attacks. LDAP channel binding prevents LDAP relay attacks by binding the LDAP authentication to the underlying TLS channel, ensuring that authentication tokens cannot be relayed to different servers.

When LDAP channel binding is not enforced (LdapEnforceChannelBinding < 2), attackers can perform LDAP relay attacks using NTLM authentication over LDAPS, potentially leading to unauthorized directory access and privilege escalation.

## Severity
HIGH

## Category
Domain Controllers

## Technical Details

### Registry Key Checked
- **Path**: `HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters`
- **Key**: `LdapEnforceChannelBinding`
- **Expected Value**: `2` (DWORD) - Always enforce
- **Vulnerable Values**: 
  - `0` - Never enforce channel binding
  - `1` - When supported (default on Windows Server 2022+)
  - Missing key (defaults to when supported)

### LDAP Filter Used
```
(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
```

This filter identifies Domain Controllers by checking:
- `objectCategory=computer`: Computer objects only
- `userAccountControl:1.2.840.113556.1.4.803:=8192`: UAC bit 8192 (SERVER_TRUST_ACCOUNT)

## Remediation

### Immediate Actions
1. **Enable LDAP Channel Binding Enforcement on all Domain Controllers**:
   ```powershell
   # Set registry value on each DC
   Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -Name "LdapEnforceChannelBinding" -Value 2 -Type DWord
   
   # Restart the NTDS service (requires maintenance window)
   Restart-Service -Name "NTDS" -Force
   ```

2. **Via Group Policy** (Recommended):
   - Navigate to: `Computer Configuration > Policies > Windows Settings > Security Settings > Local Policies > Security Options`
   - Set: `Domain controller: LDAP server channel binding token requirements` to **Always**
   - Apply to Domain Controllers OU

### Verification
```powershell
# Verify the setting on each DC
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -Name "LdapEnforceChannelBinding"

# Check via Group Policy
gpresult /h gpresult.html
# Look for "Domain controller: LDAP server channel binding token requirements"
```

### Additional Hardening
1. **Enable LDAP Signing**: Set `LDAPServerIntegrity` to 2 (Require signing)
2. **Require LDAPS**: Configure clients to use LDAPS (port 636) instead of LDAP (port 389)
3. **Network Segmentation**: Isolate Domain Controllers in dedicated network segments
4. **Monitor LDAP Traffic**: Implement monitoring for LDAP relay attempts

## Impact of Vulnerability

### Attack Scenarios
1. **LDAP Relay Attacks**: Attackers can relay NTLM authentication from LDAPS connections
2. **Credential Harvesting**: Capture and reuse authentication tokens
3. **Privilege Escalation**: Use relayed credentials to access directory services
4. **Directory Manipulation**: Unauthorized modification of directory objects

### Business Impact
- **Confidentiality**: Unauthorized access to sensitive directory data
- **Integrity**: Potential modification of directory objects and policies
- **Availability**: Risk of directory service disruption
- **Compliance**: Violation of security frameworks (NIST, CIS, STIG)

## Technical Background

### Channel Binding Mechanism
LDAP channel binding works by:
1. Creating a unique token based on the TLS channel properties
2. Binding NTLM authentication to this channel token
3. Preventing authentication tokens from being used on different TLS channels
4. Blocking relay attacks that attempt to use captured tokens elsewhere

### Windows Server Versions
- **Windows Server 2019 and earlier**: Default value is 0 (Never)
- **Windows Server 2022+**: Default value is 1 (When supported)
- **Best Practice**: Always set to 2 (Always) for maximum security

## References
- [Microsoft LDAP Channel Binding Documentation](https://learn.microsoft.com/en-us/troubleshoot/windows-server/identity/ldap-channel-binding-and-ldap-signing)
- [NIST SP 800-53 SC-8: Transmission Confidentiality and Integrity](https://nvd.nist.gov/800-53/Rev4/control/SC-8)
- [CIS Controls v8: 3.10 Encrypt Sensitive Data in Transit](https://www.cisecurity.org/controls/v8)
- [Windows Server Security Baseline](https://learn.microsoft.com/en-us/windows/security/threat-protection/windows-security-baselines)

## MITRE ATT&CK
- **Technique**: T1557 (Adversary-in-the-Middle)
- **Sub-technique**: LDAP relay attacks using NTLM authentication over LDAPS
- **Tactic**: Credential Access, Collection
- **Description**: Adversaries may attempt to position themselves between two or more networked devices to intercept communications

## Detection Notes
- **False Positives**: Minimal - LDAP channel binding should always be enforced on Domain Controllers
- **False Negatives**: May occur if remote registry access is blocked (reported as UNKNOWN)
- **Limitations**: Requires administrative privileges for remote registry access
- **Alternative Detection**: Monitor for LDAP relay attack patterns in network traffic

## File Implementations
- **adsi.ps1**: Native ADSI implementation with remote registry access
- **powershell.ps1**: PowerShell AD module with Invoke-Command for registry checks
- **cmd.bat**: Command-line implementation using dsquery and reg query
- **csharp.cs**: C# implementation using DirectoryServices and Registry classes
- **combined_multiengine.ps1**: Multi-engine approach with deduplication and comprehensive reporting
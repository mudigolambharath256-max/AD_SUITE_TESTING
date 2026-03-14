# DCs LDAP Signing Not Required

## Description
This check identifies Domain Controllers that do not require LDAP signing, making them vulnerable to network sniffing and man-in-the-middle attacks. LDAP signing provides authentication and integrity protection for LDAP communications, preventing unauthorized interception and modification of directory queries.

When LDAP signing is not required (LDAPServerIntegrity < 2), attackers can intercept LDAP traffic, potentially capturing sensitive directory information, credentials, and performing LDAP injection attacks.

## Severity
HIGH

## Category
Domain Controllers

## Technical Details

### Registry Key Checked
- **Path**: `HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters`
- **Key**: `LDAPServerIntegrity`
- **Expected Value**: `2` (DWORD) - Require signing
- **Vulnerable Values**: 
  - `0` - None (no signing)
  - `1` - Negotiate (signing optional)
  - Missing key (defaults to negotiate)

### LDAP Filter Used
```
(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
```

This filter identifies Domain Controllers by checking:
- `objectCategory=computer`: Computer objects only
- `userAccountControl:1.2.840.113556.1.4.803:=8192`: UAC bit 8192 (SERVER_TRUST_ACCOUNT)

## Remediation

### Immediate Actions
1. **Enable LDAP Signing Requirement on all Domain Controllers**:
   ```powershell
   # Set registry value on each DC
   Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -Name "LDAPServerIntegrity" -Value 2 -Type DWord
   
   # Restart the NTDS service (requires maintenance window)
   Restart-Service -Name "NTDS" -Force
   ```

2. **Via Group Policy** (Recommended):
   - Navigate to: `Computer Configuration > Policies > Windows Settings > Security Settings > Local Policies > Security Options`
   - Set: `Domain controller: LDAP server signing requirements` to **Require signing**
   - Apply to Domain Controllers OU

### Verification
```powershell
# Verify the setting on each DC
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -Name "LDAPServerIntegrity"

# Check via Group Policy
gpresult /h gpresult.html
# Look for "Domain controller: LDAP server signing requirements"
```

### Additional Hardening
1. **Enable LDAP Channel Binding**: Set `LdapEnforceChannelBinding` to 2 (Always)
2. **Require LDAPS**: Configure clients to use LDAPS (port 636) instead of LDAP (port 389)
3. **Network Segmentation**: Isolate Domain Controllers in dedicated network segments
4. **Monitor LDAP Traffic**: Implement monitoring for unsigned LDAP connections (Event ID 2887)

## Impact of Vulnerability

### Attack Scenarios
1. **Network Sniffing**: Attackers can intercept unencrypted LDAP traffic
2. **LDAP Injection**: Modify LDAP queries to extract unauthorized information
3. **Credential Harvesting**: Capture authentication tokens in LDAP binds
4. **Directory Enumeration**: Unauthorized access to directory structure and objects

### Business Impact
- **Confidentiality**: Unauthorized access to sensitive directory data
- **Integrity**: Potential modification of LDAP queries and responses
- **Availability**: Risk of directory service disruption
- **Compliance**: Violation of security frameworks (NIST, CIS, STIG)

## References
- [Microsoft LDAP Signing Documentation](https://learn.microsoft.com/en-us/troubleshoot/windows-server/identity/enable-ldap-signing-in-windows-server)
- [NIST SP 800-53 SC-8: Transmission Confidentiality and Integrity](https://nvd.nist.gov/800-53/Rev4/control/SC-8)
- [CIS Controls v8: 3.10 Encrypt Sensitive Data in Transit](https://www.cisecurity.org/controls/v8)
- [Windows Server Security Baseline](https://learn.microsoft.com/en-us/windows/security/threat-protection/windows-security-baselines)

## MITRE ATT&CK
- **Technique**: T1040 (Network Sniffing)
- **Tactic**: Discovery, Credential Access
- **Description**: Adversaries may sniff network traffic to capture information about an environment

## Detection Notes
- **False Positives**: Minimal - LDAP signing should always be required on Domain Controllers
- **False Negatives**: May occur if remote registry access is blocked (reported as UNKNOWN)
- **Limitations**: Requires administrative privileges for remote registry access
- **Alternative Detection**: Monitor Event ID 2887 in Directory Service logs for unsigned LDAP binds

## File Implementations
- **adsi.ps1**: Native ADSI implementation with remote registry access
- **powershell.ps1**: PowerShell AD module with Invoke-Command for registry checks
- **cmd.bat**: Command-line implementation using dsquery and reg query
- **csharp.cs**: C# implementation using DirectoryServices and Registry classes
- **combined_multiengine.ps1**: Multi-engine approach with deduplication and comprehensive reporting
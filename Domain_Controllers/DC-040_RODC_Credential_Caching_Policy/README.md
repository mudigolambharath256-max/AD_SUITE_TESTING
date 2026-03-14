# DC-040: RODC Credential Caching Policy

## Overview

**Check ID**: DC-040  
**Category**: Domain Controllers  
**Severity**: HIGH  
**MITRE ATT&CK**: T1552.004 (Unsecured Credentials: Private Keys)

## Description

This check detects Read-Only Domain Controllers (RODCs) with insecure credential caching policies that may allow privileged account credentials to be cached and potentially compromised. RODCs are designed to improve authentication performance in branch offices while maintaining security through selective credential caching.

## Technical Details

### LDAP Query
```
(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=67108864))
```

### Key Attributes Analyzed
- **msDS-NeverRevealGroup**: Groups/accounts that should NEVER have credentials cached
- **msDS-RevealOnDemandGroup**: Groups/accounts that CAN have credentials cached
- **msDS-RevealedList**: Accounts whose credentials ARE currently cached
- **msDS-KrbTgtLinkBl**: Kerberos TGT link back attribute

### UAC Bit Analysis
- **67108864 (0x4000000)**: PARTIAL_SECRETS_ACCOUNT - Identifies RODCs

## Security Implications

### Critical Risks
1. **Privileged Credential Exposure**: RODCs with weak caching policies risk exposing Domain Admin, Enterprise Admin, or other privileged credentials
2. **Lateral Movement**: Compromised RODC could yield cached credentials for further network compromise
3. **Persistence**: Attackers could maintain access through cached privileged accounts

### Attack Scenarios
1. **RODC Compromise**: Physical or remote compromise of RODC in branch office
2. **Credential Harvesting**: Extraction of cached credentials from RODC database
3. **Privilege Escalation**: Use of cached privileged credentials for domain compromise

## Detection Logic

### Critical Findings
- Privileged groups not in `msDS-NeverRevealGroup`
- Privileged accounts found in `msDS-RevealedList` (currently cached)
- Privileged groups in `msDS-RevealOnDemandGroup` (allowed to cache)
- No `msDS-NeverRevealGroup` configured (all accounts cacheable)

### High Findings
- Excessive number of accounts in `msDS-RevealedList`
- Weak credential caching policy configuration

### Privileged Groups Checked
- Domain Admins
- Enterprise Admins
- Schema Admins
- Administrators (Built-in)
- Group Policy Creator Owners
- Domain Controllers
- Denied RODC Password Replication Group

## Remediation

### Immediate Actions
1. **Configure NeverRevealGroup**:
   ```powershell
   # Add privileged groups to NeverRevealGroup
   $RODC = Get-ADComputer "RODC01"
   $PrivilegedGroups = @(
       "Domain Admins",
       "Enterprise Admins", 
       "Schema Admins",
       "Administrators"
   )
   
   foreach ($Group in $PrivilegedGroups) {
       Add-ADGroupMember -Identity "Denied RODC Password Replication Group" -Members $Group
   }
   ```

2. **Review RevealOnDemandGroup**:
   ```powershell
   # Review and restrict RevealOnDemandGroup
   Get-ADComputer "RODC01" -Properties msDS-RevealOnDemandGroup
   ```

3. **Clear Cached Privileged Credentials**:
   ```powershell
   # Clear cached credentials for privileged accounts
   # This requires physical access to RODC or remote management
   ```

### Long-term Security
1. **Regular Policy Review**: Quarterly review of RODC credential caching policies
2. **Monitoring**: Implement monitoring for changes to RODC credential policies
3. **Least Privilege**: Ensure only necessary accounts can be cached on RODCs
4. **Physical Security**: Secure RODC physical access in branch offices

## Files

- **powershell.ps1**: PowerShell implementation using ActiveDirectory module with forest enumeration
- **adsi.ps1**: ADSI implementation using DirectorySearcher with comprehensive policy analysis
- **csharp.cs**: C# implementation using DirectoryServices with forest-wide detection
- **cmd.bat**: CMD implementation with limited capability and manual verification guidance
- **combined_multiengine.ps1**: Multi-engine script with automatic fallback and forest enumeration
- **README.md**: This documentation file

## Example Output

```
CheckID                 : DC-040
CheckName               : RODC Credential Caching Policy
Domain                  : contoso.com
ObjectDN                : CN=RODC01,OU=Domain Controllers,DC=contoso,DC=com
ObjectName              : RODC01
FindingDetail           : RODC credential caching policy issues: Privileged groups not in NeverRevealGroup: Domain Admins, Enterprise Admins; Total accounts with cached credentials: 15
Severity                : CRITICAL
NeverRevealGroupCount   : 3
RevealOnDemandCount     : 5
RevealedAccountsCount   : 15
IssueCount              : 2
Timestamp               : 2024-01-15T10:30:45.123Z
Engine                  : PowerShell
```

## References

- [Microsoft: RODC Credential Caching](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/rodc/read-only-domain-controller-updates)
- [MITRE ATT&CK T1552.004](https://attack.mitre.org/techniques/T1552/004/)
- [NIST SP 800-53: AC-2 Account Management](https://nvd.nist.gov/800-53/Rev4/control/AC-2)

## Version History

- **1.0**: Initial implementation with forest enumeration and comprehensive policy analysis
- **1.1**: Enhanced privileged account detection and multi-engine support
# KIRO AGENT PROMPT — BloodHound Export Block Append
## Project: AD Security Suite — Append BH CE v5 Export to All adsi.ps1 Files
## Prerequisite: All 769 adsi.ps1 files are in clean canonical state (verified)
## Target: Zero parse errors after completion

---

## WHAT THIS PASS DOES

Modifies every `adsi.ps1` in the suite with exactly **two surgical changes**:

1. **Change the `FindAll()` line** from inline pipe to variable storage
2. **Append the BloodHound CE v5 export block** at the end of the file

No other changes. No other files touched.

---

## ABSOLUTE RULES

1. **Read every file before writing it.** Confirm it is in clean canonical state.
2. **Two changes only per file.** The FindAll line fix and the BH append. Nothing else.
3. **Validate parse after every file.** Never leave a broken file.
4. **If parse fails after your edit — revert immediately.** Use `git checkout` or
   restore from the original content you read at the start of that file.
5. **The BH block must be appended AFTER the final `}` of the ForEach block.**
   Never inside it. Never before it.
6. **Use str_replace for both changes.** Never rewrite the whole file.

---

## CHANGE 1 — Store FindAll result in $results variable

Every recovered script currently ends like this:

```powershell
$searcher.FindAll() | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Check Name'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
```

Change it to this (adds `$results =` and splits the pipe to its own line):

```powershell
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Check Name'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
```

**str_replace target:**
```
$searcher.FindAll() | ForEach-Object {
```
**str_replace replacement:**
```
$results = $searcher.FindAll()
$results | ForEach-Object {
```

This works on every one of the 769 scripts because they all share the identical
`$searcher.FindAll() | ForEach-Object {` pattern after recovery.

---

## CHANGE 2 — Append BloodHound CE v5 Export Block

After the final closing `}` of the ForEach block, append the following block.

**The block is parameterised per check.** The four values to substitute are:
- `CHECKID` — the check ID from the `# ID:` header (e.g. `ACC-014`)
- `CHECKNAME` — the check name from the `# Check:` header, single quotes escaped as `''`
- `SEVERITY` — the severity from the `# Severity:` header
- `CATEGORY` — the category folder name (e.g. `Access_Control`)
- `NODETYPE` — inferred from the LDAP filter (see mapping table below)

```powershell

# ============================================================================
# BLOODHOUND EXPORT — BH CE v5
# ============================================================================
try {
    $bhSession = if ($env:ADSUITE_SESSION_ID) { $env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    $bhRoot    = if ($env:ADSUITE_OUTPUT_ROOT) { $env:ADSUITE_OUTPUT_ROOT } else { Join-Path $env:TEMP 'ADSuite_Sessions' }
    $bhDir     = Join-Path $bhRoot (Join-Path $bhSession 'bloodhound')
    if (-not (Test-Path $bhDir)) { New-Item -ItemType Directory -Path $bhDir -Force -ErrorAction Stop | Out-Null }

    $bhNodes = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($r in $results) {
        $p    = $r.Properties
        $dn   = if ($p['distinguishedname'].Count -gt 0) { [string]$p['distinguishedname'][0] } else { '' }
        $name = if ($p['name'].Count -gt 0)              { [string]$p['name'][0] }              else { '' }
        $sam  = if ($p['samaccountname'].Count -gt 0)    { [string]$p['samaccountname'][0] }    else { '' }
        $uac  = if ($p['useraccountcontrol'].Count -gt 0) { [int]$p['useraccountcontrol'][0] }  else { 0 }
        $dom  = (($dn -split ',') | Where-Object { $_ -match '^DC=' } |
                  ForEach-Object { ($_ -replace '^DC=','').ToUpper() }) -join '.'
        $oid  = if ($dn) { $dn.ToUpper() } else { [guid]::NewGuid().ToString() }
        $sidRaw = if ($p['objectsid'].Count -gt 0) { $p['objectsid'][0] } else { $null }
        if ($sidRaw) { try { $oid = (New-Object System.Security.Principal.SecurityIdentifier([byte[]]$sidRaw, 0)).Value } catch { } }
        $bhNodes.Add(@{
            ObjectIdentifier = $oid
            Properties = @{
                name              = if ($dom -and $name) { "$($name.ToUpper())@$dom" } else { $name.ToUpper() }
                domain            = $dom
                distinguishedname = $dn.ToUpper()
                samaccountname    = $sam
                enabled           = -not ($uac -band 2)
                adSuiteCheckId    = 'CHECKID'
                adSuiteCheckName  = 'CHECKNAME'
                adSuiteSeverity   = 'SEVERITY'
                adSuiteCategory   = 'CATEGORY'
                adSuiteFlag       = $true
            }
            Aces           = @()
            IsDeleted      = $false
            IsACLProtected = $false
        })
    }
    $bhTs = Get-Date -Format 'yyyyMMdd_HHmmss'
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'NODETYPE'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress |
        Out-File -FilePath (Join-Path $bhDir "CHECKID_$bhTs.json") -Encoding UTF8 -Force
} catch { }
# ============================================================================
```

---

## NODE TYPE MAPPING TABLE

Use the LDAP filter in the script to determine `NODETYPE`. The rule is:

| LDAP filter contains | NODETYPE |
|---|---|
| `objectCategory=person` or `objectClass=user` (no computer) | `users` |
| `objectCategory=computer` or `objectClass=computer` | `computers` |
| `objectCategory=group` or `objectClass=group` | `groups` |
| `objectClass=domainDNS` or `objectClass=domain` | `domains` |
| `objectClass=groupPolicyContainer` | `gpos` |
| `objectClass=organizationalUnit` | `ous` |
| `objectClass=pKICertificateTemplate` or `pKIEnrollmentService` | `containers` |
| `objectClass=trustedDomain` | `domains` |
| `objectClass=attributeSchema` or `classSchema` | `containers` |
| `objectClass=site` or `subnet` or `siteLink` | `containers` |
| Category folder is `Certificate_Services` or `PKI_Services` | `containers` |
| Category folder is `Trust_Management` or `Trust_Relationships` | `domains` |
| Anything else | `users` |

---

## COMPLETE PER-CHECK METADATA

The following table gives **exact values** for CHECKID, CHECKNAME, SEVERITY, CATEGORY,
and NODETYPE for every check in the original 364-check zip. For the 405 additional checks
restored from git (new categories: ADV, BCK, CMGMT, COMPLY, LDAP, NET, PERS, SMB, etc.),
read the values directly from the `# Check:`, `# Severity:`, `# ID:`, and `# Category:`
header lines at the top of each adsi.ps1 file, and infer NODETYPE from the LDAP filter
using the mapping table above.

```
AAD-001  users       high      Azure_AD_Integration   Azure AD Connect Accounts (MSOL_*)
AAD-002  users       high      Azure_AD_Integration   Azure AD Connect Accounts (AAD_*)
AAD-003  computers   high      Azure_AD_Integration   Seamless SSO Computer Account (AZUREADSSOACC)
AAD-004  users       critical  Azure_AD_Integration   AAD Connect Accounts with Admin Rights
AAD-005  users       high      Azure_AD_Integration   Sync Accounts with Password Never Expires
AAD-006  users       medium    Azure_AD_Integration   Sync Accounts with Old Passwords (180+ Days)
AAD-007  users       critical  Azure_AD_Integration   Sync Accounts with SIDHistory
AAD-008  groups      high      Azure_AD_Integration   AAD DC Administrators Group
AAD-009  users       info      Azure_AD_Integration   Accounts Synced to Azure AD (UPN Set)
AAD-010  users       info      Azure_AD_Integration   Accounts with ms-DS-ConsistencyGuid
AAD-011  users       low       Azure_AD_Integration   Accounts with Cloud Keywords in Description
AAD-012  groups      info      Azure_AD_Integration   Azure AD Provisioning Groups
AAD-013  users       info      Azure_AD_Integration   Device Registration Service Account
AAD-014  users       high      Azure_AD_Integration   Password Hash Sync Enabled Indicators
AAD-015  users       high      Azure_AD_Integration   Passthrough Authentication Indicators
AAD-016  users       high      Azure_AD_Integration   Federation Service Accounts
AAD-017  users       critical  Azure_AD_Integration   Sync Accounts in Domain Admins
AAD-018  users       high      Azure_AD_Integration   Entra ID Connect Cloud Sync Accounts
AAD-019  users       info      Azure_AD_Integration   Accounts with ProxyAddresses (Mail-Enabled)
AAD-020  computers   info      Azure_AD_Integration   Sync Server Computer Accounts
AAD-021  users       info      Azure_AD_Integration   Service Principals with Azure in Name
AAD-022  users       low       Azure_AD_Integration   Accounts Blocked from Sync
AAD-023  containers  info      Azure_AD_Integration   Directory Sync Status Container
AAD-024  computers   info      Azure_AD_Integration   Hybrid Azure AD Joined Devices
AAD-025  users       info      Azure_AD_Integration   Accounts with Azure AD Device Registration
AAD-026  users       medium    Azure_AD_Integration   Sync Account Last Logon
AAD-027  users       info      Azure_AD_Integration   Azure AD Application Proxy Connectors
AAD-028  users       info      Azure_AD_Integration   Writeback Enabled Indicators
AAD-029  users       info      Azure_AD_Integration   Accounts with ExtensionAttributes (Exchange)
AAD-030  users       high      Azure_AD_Integration   Hybrid Identity Security Summary
ACC-001  users       high      Access_Control         Privileged Users (adminCount=1)
ACC-002  groups      high      Access_Control         Privileged Groups (adminCount=1)
ACC-003  computers   medium    Access_Control         Privileged Computers (adminCount=1)
ACC-004  users       high      Access_Control         Users with SIDHistory
ACC-006  computers   high      Access_Control         Computers with RBCD
ACC-007  users       high      Access_Control         Users with RBCD
ACC-009  computers   high      Access_Control         KeyCredentialLink on Computers
ACC-010  ous         info      Access_Control         Control Delegations - OU Level
ACC-011  users       high      Access_Control         Trust Accounts for Delegation
ACC-012  users       medium    Access_Control         Users Can Create DNS Records
ACC-013  gpos        info      Access_Control         GPO Folder Rights Review
ACC-014  groups      critical  Access_Control         Domain Admins Group Members
ACC-015  groups      critical  Access_Control         Enterprise Admins Group Members
ACC-016  groups      high      Access_Control         Schema Admins Group Members
ACC-017  groups      high      Access_Control         Backup Operators Group Members
ACC-018  groups      high      Access_Control         Server Operators Group Members
ACC-019  groups      high      Access_Control         Account Operators Group Members
ACC-020  groups      medium    Access_Control         Print Operators Group Members
ACC-021  groups      high      Access_Control         DNS Admins Group Members
ACC-022  groups      info      Access_Control         Remote Desktop Users Group Members
ACC-023  groups      info      Access_Control         Distributed COM Users Group Members
ACC-024  groups      info      Access_Control         Performance Log Users Group Members
ACC-025  domains     info      Access_Control         Users Can Add Computers to Domain
ACC-026  users       high      Access_Control         Accounts with Reversible Encryption Enabled
ACC-027  users       info      Access_Control         Key Admins Group Members
ACC-028  groups      info      Access_Control         Group Policy Creator Owners Members
ACC-029  groups      info      Access_Control         Cert Publishers Group Members
ACC-030  users       info      Access_Control         Accounts with Not Delegated Flag
AUTH-001 users       critical  Authentication         Accounts Without Kerberos Pre-Auth
AUTH-002 users       high      Authentication         Accounts with Reversible Encryption
AUTH-003 users       high      Authentication         Accounts with Password Not Required
AUTH-004 users       medium    Authentication         Accounts with Never Expiring Password
AUTH-005 users       medium    Authentication         Locked Out Accounts
AUTH-006 users       low       Authentication         Accounts Requiring Password Change
AUTH-007 users       medium    Authentication         Smart Card Required Accounts
AUTH-008 users       high      Authentication         Service Accounts SPN Set
AUTH-009 users       info      Authentication         Protected Users Group Members
AUTH-010 users       high      Authentication         Accounts Using DES Encryption
AUTH-011 domains     info      Authentication         Default Password Policy
AUTH-012 containers  info      Authentication         Fine-Grained Password Policies
AUTH-013 users       critical  Authentication         Accounts with userPassword Attribute
AUTH-014 users       critical  Authentication         Accounts with unixUserPassword
AUTH-015 users       info      Authentication         gMSA Accounts Best Practice
AUTH-016 users       high      Authentication         Accounts with altSecurityIdentities
AUTH-017 users       info      Authentication         Accounts Not Allowed to Delegate
AUTH-018 users       high      Authentication         Admin Accounts Without Delegation Protection
AUTH-019 users       high      Authentication         Native Administrator Account
AUTH-020 users       medium    Authentication         Native Guest Account
AUTH-021 users       low       Authentication         Accounts with Description Field
AUTH-022 users       low       Authentication         Accounts with Logon Scripts
AUTH-023 users       low       Authentication         Accounts with Home Directories
AUTH-024 users       low       Authentication         Accounts with Profile Paths
AUTH-025 users       low       Authentication         Accounts with Workstation Restrictions
AUTH-026 users       low       Authentication         Accounts with Logon Hours Restrictions
AUTH-027 users       low       Authentication         Accounts with Account Expiration
AUTH-028 containers  info      Authentication         Authentication Policy Silos
AUTH-029 domains     info      Authentication         Anonymous LDAP Access Check
AUTH-030 users       critical  Authentication         KRBTGT Password Age
CERT-001 containers  info      Certificate_Services   Certificate Template Inventory
CERT-002 containers  critical  Certificate_Services   ESC1 Templates Allowing SAN Specification
CERT-003 containers  critical  Certificate_Services   ESC2 Templates with Any Purpose EKU
CERT-004 containers  critical  Certificate_Services   ESC3 Templates with Certificate Request Agent
CERT-005 containers  critical  Certificate_Services   ESC4 Templates with Weak Access Control
CERT-006 containers  high      Certificate_Services   Templates Allowing Client Authentication
CERT-007 containers  high      Certificate_Services   Templates Allowing Smart Card Logon
CERT-008 containers  high      Certificate_Services   Templates Allowing PKINIT Client Auth
CERT-009 containers  medium    Certificate_Services   Templates Allowing Code Signing
CERT-010 containers  high      Certificate_Services   Templates Without Manager Approval
CERT-011 containers  high      Certificate_Services   Templates Without Authorized Signatures Required
CERT-012 containers  high      Certificate_Services   Enterprise Certificate Authorities
CERT-013 containers  high      Certificate_Services   NTAuth Certificate Store
CERT-014 containers  info      Certificate_Services   Trusted Root CAs in AD
CERT-015 containers  medium    Certificate_Services   Templates with No Expiration Validation
CERT-016 containers  medium    Certificate_Services   Templates Allowing Key Archival
CERT-017 containers  high      Certificate_Services   Templates with Exportable Private Key
CERT-018 containers  info      Certificate_Services   Templates for Machine Certificates
CERT-019 containers  medium    Certificate_Services   Templates Allowing Renewal with Different Key
CERT-020 containers  critical  Certificate_Services   ESC6 CA Allowing SAN in Requests
CERT-021 containers  critical  Certificate_Services   ESC7 CA with Manage Certificates Permission
CERT-022 containers  critical  Certificate_Services   ESC8 NTLM Relay to Web Enrollment
CERT-023 users       info      Certificate_Services   Accounts with Certificate Published
CERT-024 computers   info      Certificate_Services   Computers with Certificate Published
CERT-025 containers  info      Certificate_Services   CRL Distribution Points
CERT-026 containers  high      Certificate_Services   Templates Enrolled by Everyone
CERT-027 containers  info      Certificate_Services   Offline Root CA References
CERT-028 containers  info      Certificate_Services   AIA Authority Information Access Objects
CERT-029 containers  high      Certificate_Services   Templates with Subject Name from AD
CERT-030 containers  info      Certificate_Services   Certificate Templates Version
CMP-001  computers   high      Computers_Servers      Computers with Unconstrained Delegation
CMP-002  computers   high      Computers_Servers      Computers with Constrained Delegation
CMP-003  computers   high      Computers_Servers      Computers with RBCD Configured
CMP-004  computers   info      Computers_Servers      Computers with LAPS Deployed
CMP-005  computers   high      Computers_Servers      Computers Missing LAPS
CMP-006  computers   critical  Computers_Servers      Computers Running Unsupported OS
CMP-007  computers   medium    Computers_Servers      Stale Computer Accounts (90+ Days)
CMP-008  computers   high      Computers_Servers      Computers with adminCount=1
CMP-009  computers   high      Computers_Servers      Computers with SIDHistory
CMP-010  computers   high      Computers_Servers      Computers with KeyCredentialLink
CMP-011  computers   info      Computers_Servers      Windows Servers Inventory
CMP-012  computers   info      Computers_Servers      Windows Workstations Inventory
CMP-013  computers   high      Computers_Servers      Computers with S4U Delegation
CMP-014  computers   high      Computers_Servers      Computers with DES-Only Kerberos
CMP-015  computers   medium    Computers_Servers      Computers Missing Encryption Types
CMP-016  computers   high      Computers_Servers      Computers with Reversible Encryption
CMP-017  computers   high      Computers_Servers      Computers Trusted as DCs Not Actual DCs
CMP-018  computers   high      Computers_Servers      Computers with Pre-2000 Compatible Access
CMP-019  computers   low       Computers_Servers      Computers Created in Last 7 Days
CMP-020  computers   low       Computers_Servers      Disabled Computer Accounts
CMP-021  computers   critical  Computers_Servers      Computers with userPassword Attribute
CMP-022  computers   medium    Computers_Servers      Computers with Description Containing Sensitive Info
CMP-023  computers   medium    Computers_Servers      Computers in Default Computers Container
CMP-024  computers   high      Computers_Servers      Computers with Service Principal Names
CMP-025  computers   high      Computers_Servers      Computers with AltSecurityIdentities
CMP-026  computers   medium    Computers_Servers      Computer Accounts with Old Password (1 Year)
CMP-027  computers   info      Computers_Servers      Computers - Windows 10 Versions
CMP-028  computers   info      Computers_Servers      Computers - Windows 11 Versions
CMP-029  computers   info      Computers_Servers      Linux/Unix Computers
CMP-030  computers   info      Computers_Servers      Computers with Managed Password (gMSA Hosts)
DC-001   computers   info      Domain_Controllers     Domain Controllers Inventory
DC-002   computers   critical  Domain_Controllers     DCs with Constrained Delegation
DC-003   computers   critical  Domain_Controllers     DCs with Constrained Delegation
DC-004   domains     high      Domain_Controllers     DFSR SYSVOL Migration Status
DC-005   domains     high      Domain_Controllers     FRS SYSVOL Deprecated
DC-006   computers   info      Domain_Controllers     RODC Inventory
DC-007   containers  info      Domain_Controllers     FSMO Role Holders
DC-008   domains     info      Domain_Controllers     Schema Master
DC-009   computers   critical  Domain_Controllers     DCs with SMB Signing Disabled
DC-010   computers   critical  Domain_Controllers     DCs LDAP Signing Not Required
DC-011   computers   critical  Domain_Controllers     DCs LDAP Channel Binding Disabled
DC-012   computers   high      Domain_Controllers     DCs with Expiring Certificates
DC-013   computers   high      Domain_Controllers     DCs Replication Failures
DC-014   computers   high      Domain_Controllers     DCs Null Session Enabled
DC-015   computers   critical  Domain_Controllers     DCs with Print Spooler Running
DC-016   computers   high      Domain_Controllers     DC Accounts Not Protected
DC-017   computers   high      Domain_Controllers     DCs with Weak Kerberos Encryption
DC-018   computers   critical  Domain_Controllers     DCs with Unsigned LDAP Binds Allowed
DC-019   computers   high      Domain_Controllers     DCs Not Configured for Secure Time Sync
DC-020   computers   high      Domain_Controllers     DCs with Excessive Open Ports
DC-021   computers   high      Domain_Controllers     DCs with Local Admin Accounts
DC-022   computers   critical  Domain_Controllers     DCs Missing Critical Security Updates
DC-023   computers   high      Domain_Controllers     DCs with Weak Audit Policy
DC-024   computers   high      Domain_Controllers     DCs with RDP Enabled
DC-025   computers   high      Domain_Controllers     DCs with Insecure DNS Configuration
DC-026   computers   high      Domain_Controllers     DCs with Disabled Windows Firewall
DC-027   computers   medium    Domain_Controllers     DCs with Excessive Service Accounts
DC-028   computers   critical  Domain_Controllers     DCs with Old DSRM Password
DC-029   computers   high      Domain_Controllers     DCs with Insecure Share Permissions
DC-030   computers   high      Domain_Controllers     DCs with Disabled Security Event Log
DC-031   computers   medium    Domain_Controllers     DCs with Unsigned Drivers Allowed
DC-032   computers   high      Domain_Controllers     DCs with PowerShell v2 Enabled
GPO-001  gpos        info      Group_Policy           GPO Inventory (All)
GPO-002  gpos        info      Group_Policy           GPOs by Organizational Unit
GPO-003  gpos        low       Group_Policy           GPOs with Both Settings Disabled
GPO-004  gpos        medium    Group_Policy           GPOs Missing SYSVOL Path
GPO-005  gpos        info      Group_Policy           GPOs with WMI Filters
GPO-006  gpos        critical  Group_Policy           GPO Containing Password Naming
GPO-007  gpos        info      Group_Policy           Default Domain Policy
GPO-008  gpos        info      Group_Policy           Default Domain Controllers Policy
GPO-009  gpos        low       Group_Policy           GPOs Created Recently (7 Days)
GPO-010  gpos        low       Group_Policy           GPOs Modified Recently
GPO-011  domains     info      Group_Policy           Domain Password Policy from Domain Object
GPO-012  containers  info      Group_Policy           Fine-Grained Password Policies
GPO-013  ous         info      Group_Policy           OUs Without GPO Links
GPO-014  ous         medium    Group_Policy           OUs Blocking Inheritance
GPO-015  gpos        info      Group_Policy           GPOs with Enforced Links
GPO-016  gpos        info      Group_Policy           Starter GPOs
GPO-017  containers  info      Group_Policy           WMI Filters Inventory
GPO-018  gpos        info      Group_Policy           GPO Links on Domain Root
GPO-019  gpos        info      Group_Policy           GPO Links on Sites
GPO-020  gpos        high      Group_Policy           Credential Guard GPO Check
GPO-021  gpos        high      Group_Policy           AppLocker GPO Check
GPO-022  gpos        high      Group_Policy           BitLocker GPO Check
GPO-023  gpos        high      Group_Policy           LAPS GPO Check
GPO-024  gpos        high      Group_Policy           Audit Policy GPO Check
GPO-025  gpos        high      Group_Policy           Firewall GPO Check
GPO-026  gpos        high      Group_Policy           PowerShell Logging GPO Check
GPO-027  gpos        high      Group_Policy           Security Baseline GPO Check
GPO-028  gpos        medium    Group_Policy           WSUS GPO Check
GPO-029  gpos        medium    Group_Policy           UAC GPO Check
GPO-030  gpos        medium    Group_Policy           Remote Desktop GPO Check
KRB-001  users       high      Kerberos_Security      Kerberoastable User Accounts
KRB-002  users       critical  Kerberos_Security      AS-REP Roastable Accounts
KRB-003  computers   high      Kerberos_Security      Unconstrained Delegation Computers
KRB-004  users       high      Kerberos_Security      Unconstrained Delegation Users
KRB-005  computers   high      Kerberos_Security      Constrained Delegation Computers
KRB-006  users       high      Kerberos_Security      Constrained Delegation Users
KRB-007  users       high      Kerberos_Security      Protocol Transition (S4U2Self)
KRB-008  computers   high      Kerberos_Security      Resource-Based Constrained Delegation
KRB-009  users       high      Kerberos_Security      DES-Only Kerberos Users
KRB-010  computers   high      Kerberos_Security      DES-Only Kerberos Computers
KRB-011  users       high      Kerberos_Security      Accounts Supporting DES Encryption
KRB-012  users       medium    Kerberos_Security      Accounts Without Explicit Encryption Types
KRB-013  users       critical  Kerberos_Security      KRBTGT Account
KRB-014  domains     info      Kerberos_Security      Domain Kerberos Policy
KRB-015  users       high      Kerberos_Security      Accounts Not Delegated (Privileged)
KRB-016  users       high      Kerberos_Security      Admin Accounts Without Delegation Protection
KRB-017  users       info      Kerberos_Security      gMSA Accounts
KRB-018  users       info      Kerberos_Security      sMSA Accounts (Legacy)
KRB-019  users       high      Kerberos_Security      Kerberoastable Accounts with Old Password
KRB-020  users       critical  Kerberos_Security      AS-REP Roastable SPN Double Risk
KRB-021  users       high      Kerberos_Security      Non-Expiring Password SPN
KRB-022  users       info      Kerberos_Security      Protected Users Group Members
KRB-023  users       info      Kerberos_Security      Accounts with AES256 Only
KRB-024  computers   high      Kerberos_Security      Domain Controllers Encryption Types
KRB-025  computers   high      Kerberos_Security      Computers with Protocol Transition
KRB-026  domains     info      Kerberos_Security      Trust Accounts (TDOs)
KRB-027  users       high      Kerberos_Security      Sensitive Accounts Without AES
KRB-028  computers   high      Kerberos_Security      SPN Duplicates Check (Computers)
KRB-029  containers  info      Kerberos_Security      Authentication Policy Silos
KRB-030  containers  info      Kerberos_Security      Authentication Policies
PRV-001  groups      critical  Privileged_Access      Membership Domain Admins
PRV-002  groups      critical  Privileged_Access      Membership Enterprise Admins
PRV-003  groups      critical  Privileged_Access      Membership Schema Admins
PRV-004  groups      critical  Privileged_Access      Membership Administrators
PRV-005  groups      high      Privileged_Access      Membership Account Operators
PRV-006  groups      high      Privileged_Access      Membership Backup Operators
PRV-007  groups      high      Privileged_Access      Membership Server Operators
PRV-008  groups      medium    Privileged_Access      Membership Print Operators
PRV-009  groups      high      Privileged_Access      Membership DnsAdmins
PRV-010  groups      medium    Privileged_Access      Membership Group Policy Creator Owners
PRV-011  groups      medium    Privileged_Access      Membership Cert Publishers
PRV-012  groups      info      Privileged_Access      Membership Remote Desktop Users
PRV-013  groups      high      Privileged_Access      Membership Key Admins
PRV-014  groups      high      Privileged_Access      Membership Enterprise Key Admins
PRV-015  users       high      Privileged_Access      Privileged Users (adminCount=1)
PRV-016  computers   high      Privileged_Access      Privileged Computers (adminCount=1)
PRV-017  users       high      Privileged_Access      Admin Accounts with Non-Expiring Password
PRV-018  users       critical  Privileged_Access      Admin Accounts with SPNs (Kerberoasting Risk)
PRV-019  users       high      Privileged_Access      Admin Accounts Not in Protected Users
PRV-020  users       high      Privileged_Access      Admin Accounts That Can Be Delegated
PRV-021  groups      info      Privileged_Access      Protected Users Group Members
PRV-022  groups      info      Privileged_Access      Denied RODC Password Replication Group
PRV-023  groups      info      Privileged_Access      Allowed RODC Password Replication Group
PRV-024  groups      high      Privileged_Access      Pre-Windows 2000 Compatible Access Members
PRV-025  groups      high      Privileged_Access      Incoming Forest Trust Builders
PRV-026  containers  info      Privileged_Access      AdminSDHolder Object
PRV-027  groups      high      Privileged_Access      Exchange Windows Permissions Group
PRV-028  groups      high      Privileged_Access      Exchange Trusted Subsystem Group
PRV-029  users       high      Privileged_Access      Admin Accounts with Reversible Encryption
PRV-030  users       high      Privileged_Access      Admin Accounts with DES Encryption
SVC-001  users       high      Service_Accounts       Service Accounts SPN Inventory
SVC-002  users       high      Service_Accounts       Service Accounts with Password Never Expires
SVC-003  users       critical  Service_Accounts       Service Accounts with Kerberos Pre-Auth Disabled
SVC-004  users       high      Service_Accounts       Service Accounts with DES Only
SVC-005  users       high      Service_Accounts       Service Accounts Advertising DES Support
SVC-006  users       medium    Service_Accounts       Service Accounts Missing msDS-SupportedEncryptionTypes
SVC-007  users       critical  Service_Accounts       Service Accounts Trusted for Delegation (Unconstrained)
SVC-008  users       high      Service_Accounts       Service Accounts with Constrained Delegation Targets
SVC-009  users       high      Service_Accounts       Service Accounts Marked adminCount=1
SVC-010  users       high      Service_Accounts       Service Accounts with SIDHistory
SVC-011  users       high      Service_Accounts       Service Accounts with Password Not Required
SVC-012  users       high      Service_Accounts       Service Accounts with Reversible Encryption Allowed
SVC-013  users       high      Service_Accounts       Service Accounts with KeyCredentialLink
SVC-014  users       low       Service_Accounts       Service Accounts with Script Path
SVC-015  users       low       Service_Accounts       Service Accounts with Home Directory
SVC-016  users       low       Service_Accounts       Service Accounts with Profile Path
SVC-017  users       medium    Service_Accounts       Service Accounts with Must Change Password
SVC-018  users       high      Service_Accounts       Service Accounts not Marked Sensitive
SVC-019  users       high      Service_Accounts       Service Accounts with altSecurityIdentities
SVC-020  users       medium    Service_Accounts       Service Accounts with AccountExpires
SVC-021  users       critical  Service_Accounts       SPN Accounts - No Preauth + Non-expiring Password
SVC-022  users       critical  Service_Accounts       SPN Accounts - Unconstrained + Non-expiring Password
SVC-023  users       high      Service_Accounts       SPN Accounts with Constrained Delegation (S4U)
SVC-024  users       low       Service_Accounts       Service Accounts Missing Description
SVC-025  users       low       Service_Accounts       Service Accounts with LogonWorkstations Restriction
SVC-026  users       medium    Service_Accounts       Service Accounts Locked Out
SVC-027  users       low       Service_Accounts       Service Accounts with Email Attribute
SVC-028  users       low       Service_Accounts       Service Accounts with UPN Suffix Outside Standard
SVC-029  users       high      Service_Accounts       Service Accounts with Password Not Required (Duplicate Guard)
SVC-030  users       high      Service_Accounts       Service Accounts Missing AES256 Support
TRST-001 domains     info      Trust_Relationships    Trust Inventory (All Trusts)
TRST-002 domains     high      Trust_Relationships    Outbound Trusts
TRST-003 domains     high      Trust_Relationships    Inbound Trusts
TRST-004 domains     high      Trust_Relationships    Bidirectional Trusts
TRST-005 domains     high      Trust_Relationships    External Trusts (Non-Forest)
TRST-006 domains     high      Trust_Relationships    Forest Trusts
TRST-007 domains     critical  Trust_Relationships    Trusts Without SID Filtering
TRST-008 domains     critical  Trust_Relationships    Trusts with SID History Enabled
TRST-009 domains     high      Trust_Relationships    Trusts Without Selective Authentication
TRST-010 domains     info      Trust_Relationships    Trusts with Selective Authentication
TRST-011 domains     high      Trust_Relationships    Realm/MIT Kerberos Trusts
TRST-012 domains     high      Trust_Relationships    Cross-Forest Trusts Encryption Types
TRST-013 domains     info      Trust_Relationships    Trust Partner Domains
TRST-014 domains     medium    Trust_Relationships    Trusts Created Recently (30 Days)
TRST-015 domains     high      Trust_Relationships    Trust Security Identifiers
TRST-016 domains     info      Trust_Relationships    Parent-Child Domain Trusts
TRST-017 domains     info      Trust_Relationships    Shortcut Trusts
TRST-018 users       info      Trust_Relationships    Foreign Security Principals
TRST-019 users       high      Trust_Relationships    Orphaned Foreign Security Principals
TRST-020 domains     critical  Trust_Relationships    Trusts with RC4 Only
TRST-021 domains     info      Trust_Relationships    Trust Attributes Analysis
TRST-022 users       medium    Trust_Relationships    Downlevel Trust Accounts
TRST-023 groups      info      Trust_Relationships    Cross-Domain Group Memberships
TRST-024 domains     info      Trust_Relationships    Trusts Last Modified
TRST-025 computers   info      Trust_Relationships    Domain Controllers from Trusted Domains
TRST-026 domains     info      Trust_Relationships    Trust Attributes - Forest Transitive
TRST-027 domains     info      Trust_Relationships    Trust Attributes - Within Forest
TRST-028 domains     high      Trust_Relationships    Trust Objects Without SecurityIdentifier
TRST-029 domains     high      Trust_Relationships    Trust Objects Without FlatName
TRST-030 domains     info      Trust_Relationships    Trust Authentication Summary
USR-001  users       critical  Users_Accounts         Accounts Vulnerable to ASRepRoasting
USR-002  users       high      Users_Accounts         Accounts Vulnerable to Kerberoasting
USR-003  users       medium    Users_Accounts         Accounts Vulnerable to Timeroasting
USR-004  users       high      Users_Accounts         Admin Accounts Not in Protected Users Group
USR-005  users       high      Users_Accounts         Admin Accounts That Can Be Delegated
USR-006  users       high      Users_Accounts         Accounts with DES Encryption Only
USR-007  users       high      Users_Accounts         Accounts with altSecurityIdentities
USR-008  users       critical  Users_Accounts         Accounts with userPassword Attribute
USR-009  users       critical  Users_Accounts         Accounts with unixUserPassword Attribute
USR-010  users       critical  Users_Accounts         Accounts with unicodePwd Readable
USR-011  users       info      Users_Accounts         Accounts with msDS-HostServiceAccount
USR-012  users       high      Users_Accounts         Accounts with Blank Password Allowed
USR-013  users       medium    Users_Accounts         Locked Accounts
USR-014  users       high      Users_Accounts         Accounts with Never Expiring Passwords
USR-015  users       high      Users_Accounts         Accounts with Reversible Password Encryption
USR-016  users       medium    Users_Accounts         Inactive Accounts (90+ Days)
USR-017  groups      critical  Users_Accounts         Schema Admins Members
USR-018  groups      critical  Users_Accounts         Enterprise Admins Members
USR-019  groups      critical  Users_Accounts         Domain Admins Members
USR-020  users       high      Users_Accounts         Accounts That Had Admin Rights in Past
USR-021  users       high      Users_Accounts         Accounts with Password Not Required
USR-022  groups      high      Users_Accounts         Pre-Windows 2000 Compatible Access Members
USR-023  groups      high      Users_Accounts         Users in Privilege Escalation Groups
USR-024  users       low       Users_Accounts         Users with Description Field
USR-025  users       high      Users_Accounts         Native Administrator Account Recent Use
USR-026  users       info      Users_Accounts         Group Managed Service Accounts (gMSA)
USR-027  users       info      Users_Accounts         Standalone Managed Service Accounts (sMSA)
USR-028  groups      info      Users_Accounts         Protected Users Group Members
USR-029  users       high      Users_Accounts         Accounts with SID History
USR-030  users       high      Users_Accounts         Accounts with KeyCredentialLink (Shadow Credentials)
USR-031  users       high      Users_Accounts         Accounts with Constrained Delegation
USR-032  users       high      Users_Accounts         Accounts Trusted for Delegation
```

For the 405 git-restored checks (ADV, BCK, CMGMT, COMPLY, DCONF, INFRA, LDAP, NET,
PERS, PKI, PUBRES, SECACCT, SMB, TMGMT and new DC/GPO/KRB checks), read metadata
directly from the script header and infer node type from the filter using the table above.

---

## EXECUTION SCRIPT

Run this PowerShell script on the test machine. It processes all 769 adsi.ps1 files,
applies both changes atomically, validates before committing each write, and produces
a full report.

```powershell
# ============================================================================
# append_bh_export.ps1
# Usage: .\append_bh_export.ps1 -SuiteRoot "C:\users\vagrant\Desktop\AD_SUITE_TESTING"
# ============================================================================
param(
    [Parameter(Mandatory=$true)]
    [string]$SuiteRoot
)

$ErrorActionPreference = 'Stop'
$pass = 0; $fail = 0; $skip = 0
$failList = [System.Collections.Generic.List[string]]::new()

# ── Helpers ──────────────────────────────────────────────────────────────────
function Get-NodeType([string]$filter, [string]$category) {
    $f = $filter.ToLower()
    $c = $category.ToLower()
    if ($f -match 'objectcategory=person' -and $f -notmatch 'objectclass=computer') { return 'users' }
    if ($f -match 'objectcategory=computer|objectclass=computer') { return 'computers' }
    if ($f -match 'objectcategory=group|objectclass=group')       { return 'groups' }
    if ($f -match 'objectclass=domaindns|objectclass=domain(?!dns)') { return 'domains' }
    if ($f -match 'objectclass=grouppolicycontainer')             { return 'gpos' }
    if ($f -match 'objectclass=organizationalunit')               { return 'ous' }
    if ($f -match 'objectclass=pkicertificatetemplate|pkienrollmentservice') { return 'containers' }
    if ($f -match 'objectclass=trusteddomain')                    { return 'domains' }
    if ($f -match 'objectclass=attributeschema|classschema')      { return 'containers' }
    if ($f -match 'objectclass=site|objectclass=subnet|objectclass=sitelink') { return 'containers' }
    if ($c -match 'cert|pki')                                     { return 'containers' }
    if ($c -match 'trust')                                        { return 'domains' }
    if ($c -match 'computer|server')                              { return 'computers' }
    if ($c -match 'gpo|group_policy')                             { return 'gpos' }
    return 'users'
}

function Build-BhBlock([string]$checkId, [string]$checkName, [string]$severity,
                        [string]$category, [string]$nodeType) {
    # Escape single quotes in checkName for PS single-quoted string
    $safeName = $checkName -replace "'","''"
    return @"

# ============================================================================
# BLOODHOUND EXPORT - BH CE v5
# ============================================================================
try {
    `$bhSession = if (`$env:ADSUITE_SESSION_ID) { `$env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    `$bhRoot    = if (`$env:ADSUITE_OUTPUT_ROOT) { `$env:ADSUITE_OUTPUT_ROOT } else { Join-Path `$env:TEMP 'ADSuite_Sessions' }
    `$bhDir     = Join-Path `$bhRoot (Join-Path `$bhSession 'bloodhound')
    if (-not (Test-Path `$bhDir)) { New-Item -ItemType Directory -Path `$bhDir -Force -ErrorAction Stop | Out-Null }
    `$bhNodes = [System.Collections.Generic.List[hashtable]]::new()
    foreach (`$r in `$results) {
        `$p    = `$r.Properties
        `$dn   = if (`$p['distinguishedname'].Count -gt 0) { [string]`$p['distinguishedname'][0] } else { '' }
        `$name = if (`$p['name'].Count -gt 0)              { [string]`$p['name'][0] }              else { '' }
        `$sam  = if (`$p['samaccountname'].Count -gt 0)    { [string]`$p['samaccountname'][0] }    else { '' }
        `$uac  = if (`$p['useraccountcontrol'].Count -gt 0) { [int]`$p['useraccountcontrol'][0] }  else { 0 }
        `$dom  = ((`$dn -split ',') | Where-Object { `$_ -match '^DC=' } |
                  ForEach-Object { (`$_ -replace '^DC=','').ToUpper() }) -join '.'
        `$oid  = if (`$dn) { `$dn.ToUpper() } else { [guid]::NewGuid().ToString() }
        `$sidRaw = if (`$p['objectsid'].Count -gt 0) { `$p['objectsid'][0] } else { `$null }
        if (`$sidRaw) { try { `$oid = (New-Object System.Security.Principal.SecurityIdentifier([byte[]]`$sidRaw, 0)).Value } catch { } }
        `$bhNodes.Add(@{
            ObjectIdentifier = `$oid
            Properties = @{
                name              = if (`$dom -and `$name) { "`$(`$name.ToUpper())@`$dom" } else { `$name.ToUpper() }
                domain            = `$dom
                distinguishedname = `$dn.ToUpper()
                samaccountname    = `$sam
                enabled           = -not (`$uac -band 2)
                adSuiteCheckId    = '$checkId'
                adSuiteCheckName  = '$safeName'
                adSuiteSeverity   = '$severity'
                adSuiteCategory   = '$category'
                adSuiteFlag       = `$true
            }
            Aces           = @()
            IsDeleted      = `$false
            IsACLProtected = `$false
        })
    }
    `$bhTs = Get-Date -Format 'yyyyMMdd_HHmmss'
    @{
        data = `$bhNodes.ToArray()
        meta = @{ type = '$nodeType'; count = `$bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress |
        Out-File -FilePath (Join-Path `$bhDir '${checkId}_`$bhTs.json') -Encoding UTF8 -Force
} catch { }
# ============================================================================
"@
}

# ── Main loop ─────────────────────────────────────────────────────────────────
$allAdsi = Get-ChildItem $SuiteRoot -Recurse -Filter 'adsi.ps1'
Write-Host "Processing $($allAdsi.Count) adsi.ps1 files..." -ForegroundColor Cyan

foreach ($file in $allAdsi) {
    $path    = $file.FullName
    $content = Get-Content $path -Raw

    # ── Sanity check ─────────────────────────────────────────────────────────
    if ($content -notmatch '\[ADSISearcher\]') {
        Write-Host "  SKIP (no searcher - still corrupted?): $path" -ForegroundColor Yellow
        $skip++; continue
    }
    if ($content -match '# BLOODHOUND EXPORT') {
        Write-Host "  SKIP (BH block already present): $($file.Name) in $($file.Directory.Name)" -ForegroundColor DarkGray
        $skip++; continue
    }
    if ($content -match '\$results = \$searcher\.FindAll\(\)') {
        Write-Host "  SKIP (already has results var): $($file.Name)" -ForegroundColor DarkGray
        $skip++; continue
    }

    # ── Read header metadata ─────────────────────────────────────────────────
    $checkId   = if ($content -match '# ID: (.+)')       { $matches[1].Trim() } else { 'UNKNOWN' }
    $checkName = if ($content -match '# Check: (.+)')    { $matches[1].Trim() } else { $checkId }
    $severity  = if ($content -match '# Severity: (.+)') { $matches[1].Trim() } else { 'high' }
    $category  = if ($content -match '# Category: (.+)') { $matches[1].Trim() -replace ' ','_' } else { 'Unknown' }

    # ── Infer node type ───────────────────────────────────────────────────────
    $filterMatch = [regex]::Match($content, "\[ADSISearcher\]'(.+?)'")
    $ldapFilter  = if ($filterMatch.Success) { $filterMatch.Groups[1].Value } else { '' }
    $catFolder   = $file.Directory.Parent.Name
    $nodeType    = Get-NodeType $ldapFilter $catFolder

    # ── Change 1: store FindAll result in $results ────────────────────────────
    $oldFindAll = '$searcher.FindAll() | ForEach-Object {'
    $newFindAll = '$results = $searcher.FindAll()' + "`n" + '$results | ForEach-Object {'

    if ($content -notmatch [regex]::Escape($oldFindAll)) {
        Write-Host "  WARN (FindAll pattern not found): $checkId" -ForegroundColor Yellow
        $skip++; continue
    }
    $modified = $content -replace [regex]::Escape($oldFindAll), $newFindAll

    # ── Change 2: append BH export block ─────────────────────────────────────
    $bhBlock  = Build-BhBlock $checkId $checkName $severity $category $nodeType
    $modified = $modified.TrimEnd() + "`n" + $bhBlock

    # ── Validate before writing ───────────────────────────────────────────────
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput(
        $modified, [ref]$null, [ref]$parseErrors)

    if ($parseErrors.Count -gt 0) {
        Write-Host "  FAIL (parse error after edit): $checkId — $($parseErrors[0].Message)" -ForegroundColor Red
        $failList.Add("$checkId | $path | $($parseErrors[0].Message)")
        $fail++; continue
    }

    # All good — write
    Set-Content -Path $path -Value $modified -Encoding UTF8
    Write-Host "  OK: $checkId ($nodeType)" -ForegroundColor Green
    $pass++
}

# ── Final parse sweep ─────────────────────────────────────────────────────────
Write-Host "`n=== Final Parse Sweep ===" -ForegroundColor Cyan
$sweepPass = 0; $sweepFail = 0
Get-ChildItem $SuiteRoot -Recurse -Filter 'adsi.ps1' | ForEach-Object {
    $c = Get-Content $_.FullName -Raw
    $e = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($c, [ref]$null, [ref]$e)
    if ($e.Count -eq 0) { $sweepPass++ }
    else {
        $sweepFail++
        Write-Host "  STILL BROKEN: $($_.FullName)" -ForegroundColor Red
        Write-Host "    $($e[0].Message)" -ForegroundColor DarkRed
    }
}

# ── Report ────────────────────────────────────────────────────────────────────
Write-Host "`n=== RESULTS ===" -ForegroundColor Cyan
Write-Host "  Modified : $pass"   -ForegroundColor Green
Write-Host "  Failed   : $fail"   -ForegroundColor Red
Write-Host "  Skipped  : $skip"   -ForegroundColor Yellow
Write-Host "  Parse PASS: $sweepPass" -ForegroundColor Green
Write-Host "  Parse FAIL: $sweepFail" -ForegroundColor Red

if ($failList.Count -gt 0) {
    Write-Host "`n=== FAILURES ===" -ForegroundColor Red
    $failList | ForEach-Object { Write-Host "  $_" }
}

if ($sweepFail -eq 0 -and $fail -eq 0) {
    Write-Host "`n✅ ALL FILES CLEAN — Ready for BloodHound ingest" -ForegroundColor Green
} else {
    Write-Host "`n❌ FAILURES REMAIN — Do not run BloodHound ingest yet" -ForegroundColor Red
}
```

---

## VERIFICATION AFTER RUNNING

Once the script completes with zero failures, verify one file manually:

```powershell
# Pick any check and confirm both changes are present
$sample = 'C:\users\vagrant\Desktop\AD_SUITE_TESTING\Access_Control\ACC-001_Privileged_Users_adminCount1\adsi.ps1'
$content = Get-Content $sample -Raw

# Confirm $results variable exists
$content -match '\$results = \$searcher\.FindAll\(\)'    # must be True

# Confirm BH block present
$content -match '# BLOODHOUND EXPORT'                    # must be True
$content -match '"version": 5'                           # must be True (in JSON)
$content -match 'data = \$bhNodes'                       # must be True

# Confirm no parse errors
$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$e)
$e.Count    # must be 0
```

**Target state for all 769 adsi.ps1 files:**
- Contains `$results = $searcher.FindAll()`
- Contains `# BLOODHOUND EXPORT - BH CE v5`
- Contains `data = $bhNodes.ToArray()`
- Contains `meta = @{ type = '...'; count = ...; version = 5; methods = 0 }`
- `Parser::ParseInput` returns zero errors
# KIRO AGENT PROMPT — ACL_Permissions Category
# AD Security Suite — Access Control Entry Checks
# 20 checks × 5 engines = 100 script files
# New folder: {SuiteRoot}\ACL_Permissions\
#
# ============================================================
# CRITICAL CONSTRAINTS — READ BEFORE WRITING A SINGLE LINE
# ============================================================
# 1. DO NOT touch any existing category folder or script
# 2. DO NOT change directory structure of existing checks
# 3. ONLY create: {SuiteRoot}\ACL_Permissions\ and its 20 subfolders
# 4. All 5 engines per check MUST follow the EXACT same pattern
#    as the reference scripts provided (AUTH-001 style)
# 5. The ONLY things that differ per check:
#    — Check ID, Name, Severity
#    — Target object (what object we read the ACL from)
#    — ACE detection condition (which rights / which GUID)
#    — Extra output fields
# 6. Parse-validate every .ps1 before writing using Parser::ParseFile
# 7. Silent catch blocks are FORBIDDEN — use Write-Warning
# ============================================================


# ============================================================
# WHAT THIS CATEGORY DOES (differs from all existing checks)
# ============================================================
#
# ALL existing checks query AD objects using DirectorySearcher and
# return the matching objects. ACL checks are DIFFERENT:
#
# Step 1 — LDAP: identify the TARGET object (domain, group, OU, etc.)
# Step 2 — ACL:  read its nTSecurityDescriptor / ObjectSecurity
# Step 3 — SCAN: iterate ACEs looking for dangerous rights
# Step 4 — OUTPUT: return the TRUSTEES (who has the dangerous right)
#          NOT the target object itself
#
# The output objects are the ACCOUNTS (users/groups/computers) that
# hold the dangerous ACE, not the object being protected.
#
# This means the BH export nodes are the TRUSTEES, not the targets.
# ============================================================


# ============================================================
# TWO ACL QUERY PATTERNS — use the correct one per check
# ============================================================
#
# PATTERN A — Fixed Target (checks ACL-001 through ACL-014)
# Use when the target is a single well-known object:
# domain NC, AdminSDHolder, Domain Admins group, DC OU.
#
#   $targetObj = [ADSI]"LDAP://$targetDN"
#   $acl = $targetObj.ObjectSecurity
#   $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]) |
#       Where-Object { ACE_CONDITION } |
#       ForEach-Object { ... build trustee output ... }
#
#
# PATTERN B — Scan Multiple Targets (checks ACL-015 through ACL-020)
# Use when scanning all objects of a type (all DCs, all admin users, all GPOs).
#
#   $searcher.SecurityMasks = [System.DirectoryServices.SecurityMasks]::Dacl
#   $searcher.PropertiesToLoad.Add('nTSecurityDescriptor')
#   $scanResults = $searcher.FindAll()
#   foreach ($sr in $scanResults) {
#       $entry = $sr.GetDirectoryEntry()
#       $acl = $entry.ObjectSecurity
#       $targetDN = ($sr.Properties['distinguishedname'] | Select-Object -First 1)
#       $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]) |
#           Where-Object { ACE_CONDITION } |
#           ForEach-Object { ... build trustee output ... }
#   }
# ============================================================


# ============================================================
# ACE DETECTION CONDITIONS — exact PowerShell expressions
# ============================================================
#
# These Where-Object conditions are the CORE LOGIC of each check.
# Apply them INSIDE GetAccessRules() | Where-Object { HERE }
#
# -- RIGHTS-BASED CONDITIONS --
#
# GenericAll (0x10000000):
#   ($_.AccessControlType -eq 'Allow') -and
#   ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)
#
# WriteDACL (0x00040000):
#   ($_.AccessControlType -eq 'Allow') -and
#   ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)
#
# WriteOwner (0x00080000):
#   ($_.AccessControlType -eq 'Allow') -and
#   ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteOwner)
#
# GenericWrite (0x40000000):
#   ($_.AccessControlType -eq 'Allow') -and
#   ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite)
#
# AllExtendedRights (0x00000100) — no specific GUID = all extended rights:
#   ($_.AccessControlType -eq 'Allow') -and
#   ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and
#   ($null -eq $_.ObjectType -or $_.ObjectType -eq [guid]::Empty)
#
# GenericAll OR WriteDACL (for GPO checks):
#   ($_.AccessControlType -eq 'Allow') -and
#   (($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll) -or
#    ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl))
#
# -- GUID-BASED CONDITIONS (Extended Rights with specific GUID) --
#
# DCSync = DS-Replication-Get-Changes-All GUID 1131f6ad-9c07-11d1-f79f-00c04fc2dcd2:
#   ($_.AccessControlType -eq 'Allow') -and
#   ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and
#   ($_.ObjectType -eq [guid]'1131f6ad-9c07-11d1-f79f-00c04fc2dcd2')
#
# ForceChangePassword GUID 00299570-246d-11d0-a768-00aa006e0529:
#   ($_.AccessControlType -eq 'Allow') -and
#   ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and
#   ($_.ObjectType -eq [guid]'00299570-246d-11d0-a768-00aa006e0529')
#
# AddMember / Self-Membership GUID bf9679c0-0de6-11d0-a285-00aa003049e2:
#   ($_.AccessControlType -eq 'Allow') -and
#   ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::Self) -and
#   ($_.ObjectType -eq [guid]'bf9679c0-0de6-11d0-a285-00aa003049e2')
# ============================================================


# ============================================================
# TRUSTEE RESOLUTION BLOCK (same for every check)
# Place inside the ForEach-Object that processes matching ACEs
# ============================================================
#
# $trusteeSid  = $_.IdentityReference.Value   # S-1-5-21-...
# $trusteeName = $trusteeSid
# try {
#     $trusteeName = (New-Object System.Security.Principal.SecurityIdentifier($trusteeSid)).Translate(
#         [System.Security.Principal.NTAccount]).Value
# } catch { }
#
# # Skip well-known system accounts that legitimately have these rights:
# $skipSids = @('S-1-5-18','S-1-5-10','S-1-5-9')
# if ($trusteeSid -in $skipSids) { return }
#
# $dom = (($targetDN -split ',') | Where-Object { $_ -match '^DC=' } |
#         ForEach-Object { ($_ -replace '^DC=','') }) -join '.'
#
# [PSCustomObject]@{
#     Name              = $trusteeName
#     DistinguishedName = $targetDN.ToUpper()     # target object DN (for dedup grouping)
#     SamAccountName    = $trusteeName
#     Domain            = $dom
#     Engine            = 'ADSI'                  # or 'PowerShell' / 'CSharp'
#     Rights            = $_.ActiveDirectoryRights.ToString()
#     TargetObject      = $targetDN               # the object whose ACL was read
#     TrusteeSID        = $trusteeSid
# }
# ============================================================


# ============================================================
# BLOODHOUND EXPORT FOR ACL CHECKS
# ============================================================
# BH nodes are the TRUSTEE accounts, not the target objects.
# Since we only have the SID of the trustee (not their full AD record),
# use the SID directly as ObjectIdentifier.
# Attempt a secondary LDAP lookup to resolve SAM and DN.
#
# The BH meta.type should be 'users' for all ACL checks
# (most dangerous trustees are user accounts; groups are also common
# but 'users' is the safest BH type for accounts of unknown class).
#
# BH export block structure:
#
# try {
#     $bhSession = if ($env:ADSUITE_SESSION_ID) { ... } else { ... }
#     $bhRoot    = if ($env:ADSUITE_OUTPUT_ROOT) { ... } else { ... }
#     $bhDir     = Join-Path $bhRoot (Join-Path $bhSession 'bloodhound')
#     if (-not (Test-Path $bhDir)) { $null = New-Item ... }
#
#     $bhNodes = [System.Collections.Generic.List[hashtable]]::new()
#     foreach ($finding in $findings) {
#         # Try to resolve the trustee SID to a full AD object
#         $oid  = $finding.TrusteeSID
#         $bhNm = $finding.TrusteeName
#         try {
#             $tS = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$domainNC")
#             $tS.Filter = "(objectSid=$($finding.TrusteeSID))"     # NOTE: binary SID filter won't work as string
#             # Use SID string format with LDAP SID binding instead:
#             $tEntry = [ADSI]"LDAP://<SID=$($finding.TrusteeSID)>"
#             $bhNm = ($tEntry.Properties['samAccountName'] | Select-Object -First 1)
#             $dn   = ($tEntry.Properties['distinguishedName'] | Select-Object -First 1)
#             $dom  = (($dn -split ',') | Where-Object { $_ -match '^DC=' } | ForEach-Object { ($_ -replace '^DC=','').ToUpper() }) -join '.'
#             if ($bhNm) { $bhNm = "$($bhNm.ToUpper())@$dom" }
#         } catch { }
#
#         $bhNodes.Add(@{
#             ObjectIdentifier = $oid
#             Properties = @{
#                 name           = $bhNm
#                 domain         = $finding.Domain
#                 adSuiteCheckId = 'ACL-XXX'
#                 adSuiteCheckName = 'Check Name'
#                 adSuiteSeverity  = 'critical'
#                 adSuiteCategory  = 'ACL_Permissions'
#                 adSuiteFlag      = $true
#                 aclRights        = $finding.Rights
#                 aclTarget        = $finding.TargetObject
#             }
#             Aces = @(); IsDeleted = $false; IsACLProtected = $false
#         })
#     }
#     $bhTs = Get-Date -Format 'yyyyMMdd_HHmmss'
#     @{ data=$bhNodes.ToArray(); meta=@{type='users';count=$bhNodes.Count;version=5;methods=0} } |
#         ConvertTo-Json -Depth 10 -Compress |
#         Out-File -FilePath (Join-Path $bhDir "ACL-XXX_$bhTs.json") -Encoding UTF8 -Force
# } catch { Write-Warning "ACL-XXX BloodHound export error: $_" }
# ============================================================


# ============================================================
# COMPLETE CHECK SPECIFICATIONS
# ============================================================
# For each check below, Kiro must create:
#   {SuiteRoot}\ACL_Permissions\{ID}_{FolderName}\adsi.ps1
#   {SuiteRoot}\ACL_Permissions\{ID}_{FolderName}\powershell.ps1
#   {SuiteRoot}\ACL_Permissions\{ID}_{FolderName}\cmd.bat
#   {SuiteRoot}\ACL_Permissions\{ID}_{FolderName}\csharp.cs
#   {SuiteRoot}\ACL_Permissions\{ID}_{FolderName}\combined_multiengine.ps1
# ============================================================


# ──────────────────────────────────────────────────────────────
# ACL-001 — GenericAll on Domain Object
# FolderName: ACL-001_GenericAll_on_Domain_Object
# Pattern: FIXED TARGET — $domainNC
# ──────────────────────────────────────────────────────────────
Id:          ACL-001
Name:        GenericAll on Domain Object
Severity:    critical
NodeType BH: users
Partition:   dom (only $domainNC needed)
Target DN:   $domainNC   (read from RootDSE defaultNamingContext)
Pattern:     A (fixed target)

ACE condition:
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)

Extra output fields:
  Rights       = $_.ActiveDirectoryRights.ToString()
  TargetObject = $domainNC
  TrusteeSID   = $trusteeSid

CMD note: dsquery cannot detect ACL rights. cmd.bat MUST output:
  @echo off
  echo ACL-001: ACL detection requires PowerShell or ADSI engine. Use adsi.ps1 or combined_multiengine.ps1.
  echo Target: Domain NC object
  echo Right checked: GenericAll


# ──────────────────────────────────────────────────────────────
# ACL-002 — WriteDACL on Domain Object
# FolderName: ACL-002_WriteDACL_on_Domain_Object
# Pattern: FIXED TARGET — $domainNC
# ──────────────────────────────────────────────────────────────
Id:          ACL-002
Name:        WriteDACL on Domain Object
Severity:    critical
NodeType BH: users
Partition:   dom
Target DN:   $domainNC
Pattern:     A (fixed target)

ACE condition:
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)

Extra output fields:
  Rights       = 'WriteDacl'
  TargetObject = $domainNC
  TrusteeSID   = $trusteeSid


# ──────────────────────────────────────────────────────────────
# ACL-003 — WriteOwner on Domain Object
# FolderName: ACL-003_WriteOwner_on_Domain_Object
# Pattern: FIXED TARGET — $domainNC
# ──────────────────────────────────────────────────────────────
Id:          ACL-003
Name:        WriteOwner on Domain Object
Severity:    critical
NodeType BH: users
Partition:   dom
Target DN:   $domainNC
Pattern:     A (fixed target)

ACE condition:
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteOwner)

Extra output fields:
  Rights       = 'WriteOwner'
  TargetObject = $domainNC
  TrusteeSID   = $trusteeSid


# ──────────────────────────────────────────────────────────────
# ACL-004 — AllExtendedRights on Domain Object
# FolderName: ACL-004_AllExtendedRights_on_Domain_Object
# Pattern: FIXED TARGET — $domainNC
# ──────────────────────────────────────────────────────────────
Id:          ACL-004
Name:        AllExtendedRights on Domain Object
Severity:    critical
NodeType BH: users
Partition:   dom
Target DN:   $domainNC
Pattern:     A (fixed target)

ACE condition (AllExtendedRights = ExtendedRight with null/empty GUID):
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and
  ($null -eq $_.ObjectType -or $_.ObjectType -eq [guid]::Empty)

Extra output fields:
  Rights       = 'AllExtendedRights'
  TargetObject = $domainNC
  TrusteeSID   = $trusteeSid


# ──────────────────────────────────────────────────────────────
# ACL-005 — DCSync Rights (DS-Replication-Get-Changes-All)
# FolderName: ACL-005_DCSync_Rights_DS_Replication_Get_Changes_All
# Pattern: FIXED TARGET — $domainNC
# ──────────────────────────────────────────────────────────────
Id:          ACL-005
Name:        DCSync Rights DS-Replication-Get-Changes-All
Severity:    critical
NodeType BH: users
Partition:   dom
Target DN:   $domainNC
Pattern:     A (fixed target)

Extended Right GUID: 1131f6ad-9c07-11d1-f79f-00c04fc2dcd2

ACE condition:
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and
  ($_.ObjectType -ne $null) -and
  ($_.ObjectType.ToString() -eq '1131f6ad-9c07-11d1-f79f-00c04fc2dcd2')

Extra output fields:
  Rights       = 'DS-Replication-Get-Changes-All (DCSync)'
  TargetObject = $domainNC
  TrusteeSID   = $trusteeSid

Note: ALSO include DS-Replication-Get-Changes (1131f6aa-9c07-11d1-f79f-00c04fc2dcd2)
in a second pass — both are needed for full DCSync. Report them separately in output.
Output both GUIDs as separate findings if both present.


# ──────────────────────────────────────────────────────────────
# ACL-006 — GenericAll on AdminSDHolder
# FolderName: ACL-006_GenericAll_on_AdminSDHolder
# Pattern: FIXED TARGET — CN=AdminSDHolder,CN=System,$domainNC
# ──────────────────────────────────────────────────────────────
Id:          ACL-006
Name:        GenericAll on AdminSDHolder
Severity:    critical
NodeType BH: users
Partition:   sys (needs $domainNC, compute: "CN=AdminSDHolder,CN=System,$domainNC")

NC declarations needed:
  $root     = [ADSI]'LDAP://RootDSE'
  $domainNC = $root.Properties['defaultNamingContext'].Value

Target DN:   "CN=AdminSDHolder,CN=System,$domainNC"
Pattern:     A (fixed target)

ACE condition:
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)

Extra output fields:
  Rights       = 'GenericAll'
  TargetObject = "CN=AdminSDHolder,CN=System,$domainNC"
  TrusteeSID   = $trusteeSid

Why critical: ACL on AdminSDHolder propagates to ALL protected accounts every 60 min via SDProp.


# ──────────────────────────────────────────────────────────────
# ACL-007 — WriteDACL on AdminSDHolder
# FolderName: ACL-007_WriteDACL_on_AdminSDHolder
# Same pattern as ACL-006, same target DN
# ──────────────────────────────────────────────────────────────
Id:          ACL-007
Name:        WriteDACL on AdminSDHolder
Severity:    critical
Target DN:   "CN=AdminSDHolder,CN=System,$domainNC"

ACE condition:
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)

Extra fields: Rights='WriteDacl', TargetObject=AdminSDHolder DN, TrusteeSID


# ──────────────────────────────────────────────────────────────
# ACL-008 — WriteOwner on AdminSDHolder
# FolderName: ACL-008_WriteOwner_on_AdminSDHolder
# ──────────────────────────────────────────────────────────────
Id:          ACL-008
Name:        WriteOwner on AdminSDHolder
Severity:    critical
Target DN:   "CN=AdminSDHolder,CN=System,$domainNC"

ACE condition:
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteOwner)

Extra fields: Rights='WriteOwner', TargetObject=AdminSDHolder DN, TrusteeSID


# ──────────────────────────────────────────────────────────────
# ACL-009 — GenericAll on Domain Admins
# FolderName: ACL-009_GenericAll_on_Domain_Admins
# Pattern: FIXED TARGET — resolve via LDAP then bind
# ──────────────────────────────────────────────────────────────
Id:          ACL-009
Name:        GenericAll on Domain Admins
Severity:    critical
NodeType BH: users
Partition:   dom

Target resolution:
  # First, find the DA group DN via LDAP
  $daSearcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$domainNC")
  $daSearcher.Filter = '(&(objectCategory=group)(cn=Domain Admins))'
  $daSearcher.PropertiesToLoad.Add('distinguishedName') | Out-Null
  $daResult = $daSearcher.FindOne()
  $targetDN = if ($daResult) { $daResult.Properties['distinguishedname'][0] } else { "CN=Domain Admins,CN=Users,$domainNC" }
  $targetObj = [ADSI]"LDAP://$targetDN"
  $acl = $targetObj.ObjectSecurity

ACE condition:
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)

Extra fields: Rights='GenericAll', TargetObject=$targetDN, TrusteeSID


# ──────────────────────────────────────────────────────────────
# ACL-010 — WriteDACL on Domain Admins
# FolderName: ACL-010_WriteDACL_on_Domain_Admins
# Same target resolution as ACL-009
# ──────────────────────────────────────────────────────────────
Id:          ACL-010
Name:        WriteDACL on Domain Admins
Severity:    critical
ACE condition: WriteDacl (same pattern as ACL-009, change rights flag)
Extra fields: Rights='WriteDacl', TargetObject=$targetDN (DA group), TrusteeSID


# ──────────────────────────────────────────────────────────────
# ACL-011 — AddMember Rights on Domain Admins (Self-Membership)
# FolderName: ACL-011_AddMember_Rights_on_Domain_Admins
# GUID: bf9679c0-0de6-11d0-a285-00aa003049e2
# ──────────────────────────────────────────────────────────────
Id:          ACL-011
Name:        AddMember Rights on Domain Admins
Severity:    critical
Target:      Domain Admins group (same resolution as ACL-009)

Self-Membership GUID: bf9679c0-0de6-11d0-a285-00aa003049e2

ACE condition:
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::Self) -and
  ($_.ObjectType -ne $null) -and
  ($_.ObjectType.ToString() -eq 'bf9679c0-0de6-11d0-a285-00aa003049e2')

Extra fields: Rights='Self-Membership (AddMember)', TargetObject=$targetDN, TrusteeSID


# ──────────────────────────────────────────────────────────────
# ACL-012 — GenericAll on Enterprise Admins
# FolderName: ACL-012_GenericAll_on_Enterprise_Admins
# ──────────────────────────────────────────────────────────────
Id:          ACL-012
Name:        GenericAll on Enterprise Admins
Severity:    critical
Target:      Enterprise Admins group

Target resolution (same pattern as ACL-009 but different cn):
  $daSearcher.Filter = '(&(objectCategory=group)(cn=Enterprise Admins))'
  # EA is typically in forest root domain Users container

ACE condition: GenericAll (same as ACL-009)
Extra fields: Rights='GenericAll', TargetObject=$targetDN (EA group), TrusteeSID


# ──────────────────────────────────────────────────────────────
# ACL-013 — GenericAll on Domain Controllers OU
# FolderName: ACL-013_GenericAll_on_Domain_Controllers_OU
# Pattern: FIXED TARGET — find DC OU via LDAP
# ──────────────────────────────────────────────────────────────
Id:          ACL-013
Name:        GenericAll on Domain Controllers OU
Severity:    critical
NodeType BH: users
Partition:   dom

Target resolution:
  $ouSearcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$domainNC")
  $ouSearcher.Filter = '(&(objectClass=organizationalUnit)(ou=Domain Controllers))'
  $ouSearcher.PropertiesToLoad.Add('distinguishedName') | Out-Null
  $ouResult = $ouSearcher.FindOne()
  $targetDN = if ($ouResult) { $ouResult.Properties['distinguishedname'][0] } else { "OU=Domain Controllers,$domainNC" }
  $targetObj = [ADSI]"LDAP://$targetDN"
  $acl = $targetObj.ObjectSecurity

ACE condition:
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)

Extra fields: Rights='GenericAll', TargetObject=$targetDN (DC OU), TrusteeSID


# ──────────────────────────────────────────────────────────────
# ACL-014 — WriteDACL on Domain Controllers OU
# FolderName: ACL-014_WriteDACL_on_Domain_Controllers_OU
# Same target as ACL-013, change rights flag
# ──────────────────────────────────────────────────────────────
Id:          ACL-014
Name:        WriteDACL on Domain Controllers OU
Severity:    critical
Target:      Domain Controllers OU (same resolution as ACL-013)
ACE condition: WriteDacl
Extra fields: Rights='WriteDacl', TargetObject=$targetDN (DC OU), TrusteeSID


# ──────────────────────────────────────────────────────────────
# ACL-015 — ForceChangePassword on Privileged Users
# FolderName: ACL-015_ForceChangePassword_on_Privileged_Users
# Pattern: B (scan multiple targets)
# ──────────────────────────────────────────────────────────────
Id:          ACL-015
Name:        ForceChangePassword on Privileged Users
Severity:    critical
NodeType BH: users
Partition:   dom
Pattern:     B — scan all privileged users

LDAP filter for target objects:
  (&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))

SecurityMasks: Dacl
PropertiesToLoad: 'distinguishedName','name','samAccountName'

ForceChangePassword GUID: 00299570-246d-11d0-a768-00aa006e0529

ACE condition per object:
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and
  ($_.ObjectType -ne $null) -and
  ($_.ObjectType.ToString() -eq '00299570-246d-11d0-a768-00aa006e0529')

Output per matching ACE:
  Name              = $trusteeName
  DistinguishedName = $targetDN.ToUpper()     # target user's DN
  SamAccountName    = $trusteeName
  Domain            = $dom
  Engine            = 'ADSI'
  Rights            = 'ForceChangePassword'
  TargetObject      = $targetDN              # the privileged user being protected
  TrusteeSID        = $trusteeSid


# ──────────────────────────────────────────────────────────────
# ACL-016 — GenericWrite on Privileged Users
# FolderName: ACL-016_GenericWrite_on_Privileged_Users
# Same scan pattern as ACL-015
# ──────────────────────────────────────────────────────────────
Id:          ACL-016
Name:        GenericWrite on Privileged Users
Severity:    critical
LDAP filter: (&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))

ACE condition:
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite)

Extra fields: Rights='GenericWrite', TargetObject=$targetDN, TrusteeSID


# ──────────────────────────────────────────────────────────────
# ACL-017 — AllExtendedRights on Privileged Users
# FolderName: ACL-017_AllExtendedRights_on_Privileged_Users
# ──────────────────────────────────────────────────────────────
Id:          ACL-017
Name:        AllExtendedRights on Privileged Users
Severity:    high
LDAP filter: (&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))

ACE condition (AllExtendedRights = ExtendedRight with null/empty GUID):
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and
  ($null -eq $_.ObjectType -or $_.ObjectType -eq [guid]::Empty)

Extra fields: Rights='AllExtendedRights', TargetObject=$targetDN, TrusteeSID


# ──────────────────────────────────────────────────────────────
# ACL-018 — GenericAll on Domain Controller Computers
# FolderName: ACL-018_GenericAll_on_Domain_Controller_Computers
# Pattern: B (scan DCs)
# ──────────────────────────────────────────────────────────────
Id:          ACL-018
Name:        GenericAll on Domain Controller Computers
Severity:    critical
NodeType BH: computers
Partition:   dom

LDAP filter for target objects:
  (&(objectCategory=computer)(primaryGroupID=516))

SecurityMasks: Dacl
PropertiesToLoad: 'distinguishedName','name','samAccountName'

ACE condition:
  ($_.AccessControlType -eq 'Allow') -and
  ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)

Extra fields: Rights='GenericAll', TargetObject=$targetDN (DC computer object), TrusteeSID


# ──────────────────────────────────────────────────────────────
# ACL-019 — WriteDACL on Domain Controller Computers
# FolderName: ACL-019_WriteDACL_on_Domain_Controller_Computers
# Same scan as ACL-018, change rights flag
# ──────────────────────────────────────────────────────────────
Id:          ACL-019
Name:        WriteDACL on Domain Controller Computers
Severity:    critical
LDAP filter: (&(objectCategory=computer)(primaryGroupID=516))
ACE condition: WriteDacl
Extra fields: Rights='WriteDacl', TargetObject=$targetDN, TrusteeSID


# ──────────────────────────────────────────────────────────────
# ACL-020 — GenericAll or WriteDACL on GPO Objects
# FolderName: ACL-020_GenericAll_WriteDACL_on_GPO_Objects
# Pattern: B (scan all GPOs)
# ──────────────────────────────────────────────────────────────
Id:          ACL-020
Name:        GenericAll or WriteDACL on GPO Objects
Severity:    high
NodeType BH: gpos
Partition:   gpo (needs: CN=Policies,CN=System,$domainNC)

NC declarations needed:
  $root     = [ADSI]'LDAP://RootDSE'
  $domainNC = $root.Properties['defaultNamingContext'].Value
  $gpoBase  = "CN=Policies,CN=System,$domainNC"

LDAP filter for target objects:
  (objectClass=groupPolicyContainer)

SearchRoot: [ADSI]"LDAP://$gpoBase"
SecurityMasks: Dacl
PropertiesToLoad: 'distinguishedName','displayName','name'

ACE condition (GenericAll OR WriteDACL):
  ($_.AccessControlType -eq 'Allow') -and
  (($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll) -or
   ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl))

Extra fields:
  Rights       = $_.ActiveDirectoryRights.ToString()
  TargetObject = $targetDN   # GPO container DN
  GPOName      = $gpoDisplayName
  TrusteeSID   = $trusteeSid


# ============================================================
# COMPLETE ADSI.PS1 TEMPLATE FOR PATTERN A (fixed target)
# Use this verbatim for ACL-001 through ACL-014
# Replace: CHECK_ID, CHECK_NAME, SEVERITY, TARGET_DN_EXPR, ACE_CONDITION, EXTRA_FIELDS_BLOCK
# ============================================================

<# PATTERN A — adsi.ps1 TEMPLATE
# Check: CHECK_NAME
# Category: ACL_Permissions
# Severity: SEVERITY
# ID: CHECK_ID
# Requirements: None
# ============================================

$root     = [ADSI]'LDAP://RootDSE'
$domainNC = $root.Properties['defaultNamingContext'].Value

# Build target DN (varies per check — see specification above)
$targetDN  = TARGET_DN_EXPR
$targetObj = [ADSI]"LDAP://$targetDN"
$acl       = $targetObj.ObjectSecurity

$findings = [System.Collections.Generic.List[PSObject]]::new()

$skipSids = @('S-1-5-18','S-1-5-10','S-1-5-9')

$acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]) |
    Where-Object {
        ACE_CONDITION_HERE
    } | ForEach-Object {
        $trusteeSid  = $_.IdentityReference.Value
        if ($trusteeSid -in $skipSids) { return }
        $trusteeName = $trusteeSid
        try {
            $trusteeName = (New-Object System.Security.Principal.SecurityIdentifier($trusteeSid)).Translate(
                [System.Security.Principal.NTAccount]).Value
        } catch { }

        $dom = (($targetDN -split ',') | Where-Object { $_ -match '^DC=' } |
                ForEach-Object { ($_ -replace '^DC=','') }) -join '.'

        $findings.Add([PSCustomObject]@{
            Name              = $trusteeName
            DistinguishedName = $targetDN.ToUpper()
            SamAccountName    = $trusteeName
            Domain            = $dom
            Engine            = 'ADSI'
            EXTRA_FIELDS_BLOCK
        })
    }

Write-Host "CHECK_ID: found $($findings.Count) trustees with RIGHTS_DESCRIPTION on TARGET_DISPLAY"
$findings

# ── BloodHound Export ─────────────────────────────────────────────────────────
try {
    $bhSession = if ($env:ADSUITE_SESSION_ID) { $env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    $bhRoot    = if ($env:ADSUITE_OUTPUT_ROOT) { $env:ADSUITE_OUTPUT_ROOT } else { Join-Path $env:TEMP 'ADSuite_Sessions' }
    $bhDir     = Join-Path $bhRoot (Join-Path $bhSession 'bloodhound')
    if (-not (Test-Path $bhDir)) { $null = New-Item -ItemType Directory -Path $bhDir -Force -ErrorAction Stop }

    $bhNodes = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($f in $findings) {
        $oid  = $f.TrusteeSID
        $bhNm = $f.Name
        # Attempt SID-based LDAP resolution
        try {
            $tEntry = [ADSI]"LDAP://<SID=$($f.TrusteeSID)>"
            $tSam   = ($tEntry.Properties['samAccountName'] | Select-Object -First 1)
            $tDn    = ($tEntry.Properties['distinguishedName'] | Select-Object -First 1)
            $tDom   = (($tDn -split ',') | Where-Object { $_ -match '^DC=' } |
                       ForEach-Object { ($_ -replace '^DC=','').ToUpper() }) -join '.'
            if ($tSam) { $bhNm = "$($tSam.ToUpper())@$tDom" }
        } catch { }

        $bhNodes.Add(@{
            ObjectIdentifier = $oid
            Properties = @{
                name             = $bhNm
                domain           = $f.Domain
                distinguishedname = $f.DistinguishedName
                enabled          = $true
                isdeleted        = $false
                adSuiteCheckId   = 'CHECK_ID'
                adSuiteCheckName = 'CHECK_NAME'
                adSuiteSeverity  = 'SEVERITY'
                adSuiteCategory  = 'ACL_Permissions'
                adSuiteFlag      = $true
                aclRights        = $f.Rights
                aclTarget        = $f.TargetObject
            }
            Aces = @(); IsDeleted = $false; IsACLProtected = $false
        })
    }
    $bhTs = Get-Date -Format 'yyyyMMdd_HHmmss'
    @{ data = $bhNodes.ToArray()
       meta = @{ type = 'users'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress |
        Out-File -FilePath (Join-Path $bhDir "CHECK_ID_$bhTs.json") -Encoding UTF8 -Force
} catch { Write-Warning "CHECK_ID BloodHound export error: $_" }
# ── End BloodHound Export ─────────────────────────────────────────────────────
#>


# ============================================================
# COMPLETE ADSI.PS1 TEMPLATE FOR PATTERN B (scan multiple targets)
# Use this for ACL-015 through ACL-020
# ============================================================

<# PATTERN B — adsi.ps1 TEMPLATE
# Check: CHECK_NAME
# Category: ACL_Permissions
# Severity: SEVERITY
# ID: CHECK_ID
# Requirements: None
# ============================================

$root     = [ADSI]'LDAP://RootDSE'
$domainNC = $root.Properties['defaultNamingContext'].Value

# SEARCHBASE per check (dom, gpo partition etc)
$searchBase = [ADSI]"LDAP://$domainNC"  # replace for gpo checks

$searcher = New-Object System.DirectoryServices.DirectorySearcher($searchBase)
$searcher.Filter        = 'SCAN_LDAP_FILTER'
$searcher.PageSize      = 1000
$searcher.SecurityMasks = [System.DirectoryServices.SecurityMasks]::Dacl
$searcher.PropertiesToLoad.Clear()
@('distinguishedName','name','samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

$scanResults = $searcher.FindAll()
Write-Host "CHECK_ID: scanning $($scanResults.Count) target objects for ACE rights..."

$findings = [System.Collections.Generic.List[PSObject]]::new()
$skipSids  = @('S-1-5-18','S-1-5-10','S-1-5-9')

foreach ($sr in $scanResults) {
    $targetDN  = ($sr.Properties['distinguishedname'] | Select-Object -First 1)
    try {
        $entry = $sr.GetDirectoryEntry()
        $acl   = $entry.ObjectSecurity

        $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]) |
            Where-Object {
                ACE_CONDITION_HERE
            } | ForEach-Object {
                $trusteeSid  = $_.IdentityReference.Value
                if ($trusteeSid -in $skipSids) { return }
                $trusteeName = $trusteeSid
                try {
                    $trusteeName = (New-Object System.Security.Principal.SecurityIdentifier($trusteeSid)).Translate(
                        [System.Security.Principal.NTAccount]).Value
                } catch { }

                $dom = (($targetDN -split ',') | Where-Object { $_ -match '^DC=' } |
                        ForEach-Object { ($_ -replace '^DC=','') }) -join '.'

                $findings.Add([PSCustomObject]@{
                    Name              = $trusteeName
                    DistinguishedName = $targetDN.ToUpper()
                    SamAccountName    = $trusteeName
                    Domain            = $dom
                    Engine            = 'ADSI'
                    EXTRA_FIELDS_BLOCK
                })
            }
    } catch {
        Write-Warning "CHECK_ID: Failed to read ACL on $targetDN — $_"
    }
}

$scanResults.Dispose()
Write-Host "CHECK_ID: found $($findings.Count) ACE matches"
$findings

# BH Export block identical to Pattern A — same structure
# ── BloodHound Export ─────────────────────────────────────────────────────────
# [same as Pattern A above]
#>


# ============================================================
# POWERSHELL.PS1 TEMPLATE — same logic, AD module approach
# Pattern A uses Get-ADObject on specific DN then .nTSecurityDescriptor
# Pattern B uses pipeline of Get-ADObject results
# ============================================================

<# PATTERN A — powershell.ps1 TEMPLATE
# Check: CHECK_NAME
# Category: ACL_Permissions
# Severity: SEVERITY
# ID: CHECK_ID
# Requirements: ActiveDirectory module (RSAT)
# ============================================
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

try {
    $domainNC = (Get-ADDomain -ErrorAction Stop).DistinguishedName

    # Get target object and read its ACL
    $targetDN = TARGET_DN_EXPR_PS      # build same as adsi.ps1
    $targetAcl = (Get-Acl "AD:$targetDN" -ErrorAction Stop).Access

    $skipSids = @('S-1-5-18','S-1-5-10','S-1-5-9')

    $output = $targetAcl |
        Where-Object {
            ACE_CONDITION_PS_HERE      # same logic, use $_.Rights instead of $_.ActiveDirectoryRights
        } |
        ForEach-Object {
            $sid  = $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
            if ($sid -in $skipSids) { return }
            $name = $_.IdentityReference.Value
            $dom  = (($targetDN -split ',') | Where-Object { $_ -match '^DC=' } |
                     ForEach-Object { $_ -replace '^DC=','' }) -join '.'
            [PSCustomObject]@{
                Name              = $name
                DistinguishedName = $targetDN.ToUpper()
                SamAccountName    = $name
                Domain            = $dom
                Engine            = 'PowerShell'
                EXTRA_FIELDS_BLOCK_PS
            }
        }

    Write-Host "CHECK_ID: found $($output.Count) trustees"
    $output

} catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Warning "CHECK_ID: AD server unreachable — $_"
} catch {
    Write-Warning "CHECK_ID: Query failed — $_"
}
#>

# NOTE on PowerShell ACE condition syntax:
# Get-Acl "AD:$dn" returns AccessRule objects where:
#   $_.ActiveDirectoryRights is same type as ADSI
#   $_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow
#   $_.ObjectType is a GUID


# ============================================================
# CMD.BAT TEMPLATE — same for ALL ACL checks
# dsquery cannot read nTSecurityDescriptor or parse ACEs
# cmd.bat must output an informative message directing to adsi.ps1
# ============================================================

<# cmd.bat TEMPLATE for ALL ACL checks
REM Check: CHECK_NAME
REM Category: ACL_Permissions
REM Severity: SEVERITY
REM ID: CHECK_ID
REM Requirements: N/A (ACL detection not supported by dsquery)
REM ============================================
REM NOTICE: ACL/ACE permission detection requires PowerShell or ADSI.
REM dsquery cannot read nTSecurityDescriptor or enumerate Access Control Entries.
REM Use adsi.ps1 or combined_multiengine.ps1 for full ACL analysis.
REM
REM This file is intentionally limited. The check logic runs in:
REM   adsi.ps1              (ADSI / DirectorySearcher + .NET ObjectSecurity)
REM   powershell.ps1        (Get-Acl "AD:$dn")
REM   combined_multiengine.ps1 (all 3 engines)
REM   csharp.cs             (System.DirectoryServices.DirectoryEntry.ObjectSecurity)

@echo off
echo CHECK_ID: CHECK_NAME
echo ACL/ACE detection requires PowerShell or ADSI engine.
echo Run: powershell -ExecutionPolicy Bypass -File adsi.ps1
echo Or:  powershell -ExecutionPolicy Bypass -File combined_multiengine.ps1
#>


# ============================================================
# CSHARP.CS TEMPLATE — PATTERN A (fixed target)
# Uses DirectoryEntry.ObjectSecurity for ACL reading
# Outputs 5-field tab-separated format per existing AUTH-001 style
# ============================================================

<# PATTERN A — csharp.cs TEMPLATE
// Check: CHECK_NAME
// Category: ACL_Permissions
// Severity: SEVERITY
// ID: CHECK_ID
// Requirements: System.DirectoryServices (.NET 4.6.2+)
// ============================================

using System;
using System.DirectoryServices;
using System.Security.AccessControl;
using System.Security.Principal;

class Program
{
    static string GetDomain(string dn)
    {
        if (string.IsNullOrEmpty(dn)) return "";
        var parts = dn.Split(',');
        var dc = new System.Collections.Generic.List<string>();
        foreach (var p in parts)
            if (p.TrimStart().StartsWith("DC=", StringComparison.OrdinalIgnoreCase))
                dc.Add(p.TrimStart().Substring(3));
        return string.Join(".", dc);
    }

    static void Main()
    {
        string[] skipSids = new string[] { "S-1-5-18", "S-1-5-10", "S-1-5-9" };

        try
        {
            using (DirectoryEntry rootEntry = new DirectoryEntry("LDAP://RootDSE"))
            {
                string domainNC = rootEntry.Properties["defaultNamingContext"].Value.ToString();
                string targetDN = TARGET_DN_CS_EXPR;   // e.g. domainNC, or "CN=AdminSDHolder,CN=System," + domainNC

                using (DirectoryEntry targetEntry = new DirectoryEntry("LDAP://" + targetDN))
                {
                    ActiveDirectorySecurity acl = targetEntry.ObjectSecurity;
                    AuthorizationRuleCollection rules = acl.GetAccessRules(true, true, typeof(SecurityIdentifier));

                    Console.WriteLine("CHECK_ID: scanning ACL on " + targetDN);
                    Console.WriteLine("Name\tDistinguishedName\tSamAccountName\tDomain\tEngine\tRights\tTargetObject\tTrusteeSID");

                    int count = 0;
                    foreach (ActiveDirectoryAccessRule rule in rules)
                    {
                        if (rule.AccessControlType != AccessControlType.Allow) continue;

                        // ACE_CONDITION_CS — replace with correct check
                        if (!ACE_CONDITION_CS) continue;

                        string sid = rule.IdentityReference.Value;
                        bool skip = false;
                        foreach (var s in skipSids) if (sid == s) { skip = true; break; }
                        if (skip) continue;

                        string name = sid;
                        try { name = new SecurityIdentifier(sid).Translate(typeof(NTAccount)).Value; } catch { }

                        string dom = GetDomain(targetDN);
                        Console.WriteLine(name + "\t" + targetDN.ToUpper() + "\t" + name + "\t" + dom + "\tCSharp\t" + rule.ActiveDirectoryRights.ToString() + "\t" + targetDN + "\t" + sid);
                        count++;
                    }
                    Console.WriteLine("CHECK_ID: found " + count + " trustees");
                }
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("CHECK_ID error: " + ex.Message);
            Environment.Exit(1);
        }
    }
}
// C# ACE conditions:
// GenericAll:  (rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0
// WriteDACL:   (rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0
// WriteOwner:  (rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteOwner) != 0
// GenericWrite:(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericWrite) != 0
// ExtendedRight (all): (rule.ActiveDirectoryRights & ActiveDirectoryRights.ExtendedRight) != 0 && rule.ObjectType == Guid.Empty
// DCSync GUID:  rule.ObjectType == new Guid("1131f6ad-9c07-11d1-f79f-00c04fc2dcd2")
// ForceChangePwd: rule.ObjectType == new Guid("00299570-246d-11d0-a768-00aa006e0529")
// Self-Member:  (rule.ActiveDirectoryRights & ActiveDirectoryRights.Self) != 0 && rule.ObjectType == new Guid("bf9679c0-0de6-11d0-a285-00aa003049e2")
#>


# ============================================================
# COMBINED_MULTIENGINE.PS1 TEMPLATE — PATTERN A
# Follows EXACTLY the AUTH-001 combined script structure
# C# uses StringBuilder pattern (BUG1-fixed) from existing templates
# ============================================================

<# PATTERN A — combined_multiengine.ps1 TEMPLATE
# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: CHECK_NAME
# Category: ACL_Permissions
# ID: CHECK_ID
# =============================================================================

$ErrorActionPreference = 'Continue'
$allResults = [System.Collections.Generic.List[PSObject]]::new()
$engStatus  = @{}

Write-Host "=== CHECK_NAME ===" -ForegroundColor Cyan

$root     = [ADSI]'LDAP://RootDSE'
$domainNC = $root.Properties['defaultNamingContext'].Value
$targetDN = TARGET_DN_EXPR

$skipSids = @('S-1-5-18','S-1-5-10','S-1-5-9')

# ── ENGINE 1: PowerShell ──────────────────────────────────────────────────────
Write-Host "[1/3] PowerShell..." -ForegroundColor Yellow
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $targetAcl = (Get-Acl "AD:$targetDN" -ErrorAction Stop).Access

    $targetAcl |
        Where-Object { ACE_CONDITION_HERE } |
        ForEach-Object {
            $sid  = try { $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value } catch { $_.IdentityReference.Value }
            if ($sid -in $skipSids) { return }
            $name = $_.IdentityReference.Value
            $dom  = (($targetDN -split ',') | Where-Object { $_ -match '^DC=' } | ForEach-Object { $_ -replace '^DC=','' }) -join '.'
            $allResults.Add([PSCustomObject]@{
                Name              = $name
                DistinguishedName = $targetDN.ToUpper()
                SamAccountName    = $name
                Domain            = $dom
                Engine            = 'PowerShell'
                EXTRA_FIELDS_BLOCK
            })
        }
    $engStatus['PowerShell'] = "Success ($($allResults.Count))"
    Write-Host "    [OK] $($allResults.Count) results" -ForegroundColor Green
} catch {
    $engStatus['PowerShell'] = "Failed: $_"
    Write-Warning "CHECK_ID PowerShell engine: $_"
}

# ── ENGINE 2: ADSI ────────────────────────────────────────────────────────────
Write-Host "[2/3] ADSI..." -ForegroundColor Yellow
$beforeADSI = $allResults.Count
try {
    $targetObj = [ADSI]"LDAP://$targetDN"
    $acl       = $targetObj.ObjectSecurity

    $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]) |
        Where-Object { ACE_CONDITION_HERE } |
        ForEach-Object {
            $sid = $_.IdentityReference.Value
            if ($sid -in $skipSids) { return }
            $name = $sid
            try { $name = (New-Object System.Security.Principal.SecurityIdentifier($sid)).Translate([System.Security.Principal.NTAccount]).Value } catch { }
            $dom = (($targetDN -split ',') | Where-Object { $_ -match '^DC=' } | ForEach-Object { ($_ -replace '^DC=','') }) -join '.'
            $allResults.Add([PSCustomObject]@{
                Name              = $name
                DistinguishedName = $targetDN.ToUpper()
                SamAccountName    = $name
                Domain            = $dom
                Engine            = 'ADSI'
                EXTRA_FIELDS_BLOCK
            })
        }
    $engStatus['ADSI'] = "Success ($($allResults.Count - $beforeADSI))"
    Write-Host "    [OK] $($allResults.Count - $beforeADSI) results" -ForegroundColor Green
} catch {
    $engStatus['ADSI'] = "Failed: $_"
    Write-Warning "CHECK_ID ADSI engine: $_"
}

# ── ENGINE 3: C# ─────────────────────────────────────────────────────────────
Write-Host "[3/3] C#..." -ForegroundColor Yellow
$beforeCS = $allResults.Count
try {
    # Pre-expand values (BUG1 fix — outside StringBuilder, not @'...'@ literals)
    $csTargetDN  = $targetDN
    $csDomainNC  = $domainNC
    $csCheckId   = 'CHECK_ID'
    $csRightsFlag = 'ACE_RIGHTS_CS_FLAG'   # e.g. 'GenericAll', 'WriteDacl', 'WriteOwner'

    $csCode = [System.Text.StringBuilder]::new()
    [void]$csCode.AppendLine('using System;')
    [void]$csCode.AppendLine('using System.DirectoryServices;')
    [void]$csCode.AppendLine('using System.Security.AccessControl;')
    [void]$csCode.AppendLine('using System.Security.Principal;')
    [void]$csCode.AppendLine('using System.Collections.Generic;')
    [void]$csCode.AppendLine('public class ADSuiteChecker {')
    [void]$csCode.AppendLine('    private static string Dom(string dn) {')
    [void]$csCode.AppendLine('        var dc = new List<string>();')
    [void]$csCode.AppendLine('        foreach (var p in dn.Split('','')) if (p.TrimStart().StartsWith("DC=", StringComparison.OrdinalIgnoreCase)) dc.Add(p.TrimStart().Substring(3));')
    [void]$csCode.AppendLine('        return string.Join(".", dc); }')
    [void]$csCode.AppendLine('    public List<string[]> Run(string targetDN, string[] skipSids) {')
    [void]$csCode.AppendLine('        var results = new List<string[]>();')
    [void]$csCode.AppendLine('        using (var entry = new DirectoryEntry("LDAP://" + targetDN)) {')
    [void]$csCode.AppendLine('            var acl   = entry.ObjectSecurity;')
    [void]$csCode.AppendLine('            var rules = acl.GetAccessRules(true, true, typeof(SecurityIdentifier));')
    [void]$csCode.AppendLine('            foreach (ActiveDirectoryAccessRule rule in rules) {')
    [void]$csCode.AppendLine('                if (rule.AccessControlType != AccessControlType.Allow) continue;')
    # Inject ACE condition line pre-expanded:
    [void]$csCode.AppendLine("                if (!(ACE_CONDITION_CS_INLINE)) continue;")
    [void]$csCode.AppendLine('                string sid = rule.IdentityReference.Value;')
    [void]$csCode.AppendLine('                bool skip = false; foreach (var s in skipSids) if (sid == s) { skip = true; break; }')
    [void]$csCode.AppendLine('                if (skip) continue;')
    [void]$csCode.AppendLine('                string name = sid;')
    [void]$csCode.AppendLine('                try { name = new SecurityIdentifier(sid).Translate(typeof(NTAccount)).Value; } catch { }')
    [void]$csCode.AppendLine('                string dom = Dom(targetDN);')
    [void]$csCode.AppendLine('                results.Add(new string[]{ name, targetDN.ToUpper(), name, dom, rule.ActiveDirectoryRights.ToString(), targetDN, sid });')
    [void]$csCode.AppendLine('            }')
    [void]$csCode.AppendLine('        }')
    [void]$csCode.AppendLine('        return results; }')
    [void]$csCode.AppendLine('}')

    if (-not ([System.Management.Automation.PSTypeName]'ADSuiteChecker').Type) {
        $dsDll = [System.AppDomain]::CurrentDomain.GetAssemblies() |
                 Where-Object { $_.Location -like '*DirectoryServices*' } |
                 Select-Object -First 1 -ExpandProperty Location
        if ($dsDll) { Add-Type -TypeDefinition $csCode.ToString() -ReferencedAssemblies $dsDll,'System.Security.AccessControl','System.Security.Principal.Windows' -ErrorAction Stop }
        else         { Add-Type -TypeDefinition $csCode.ToString() -ReferencedAssemblies System.DirectoryServices -ErrorAction Stop }
    }

    $csSids = @('S-1-5-18','S-1-5-10','S-1-5-9')
    $csRows = (New-Object ADSuiteChecker).Run($csTargetDN, $csSids)
    foreach ($row in $csRows) {
        $allResults.Add([PSCustomObject]@{
            Name              = $row[0]
            DistinguishedName = $row[1]
            SamAccountName    = $row[2]
            Domain            = $row[3]
            Engine            = 'CSharp'
            Rights            = $row[4]
            TargetObject      = $row[5]
            TrusteeSID        = $row[6]
        })
    }
    $engStatus['CSharp'] = "Success ($($allResults.Count - $beforeCS))"
    Write-Host "    [OK] $($allResults.Count - $beforeCS) results" -ForegroundColor Green
} catch {
    $engStatus['CSharp'] = "Failed: $_"
    Write-Warning "CHECK_ID C# engine: $_"
}

# ── DEDUPLICATION ─────────────────────────────────────────────────────────────
$uniqueResults = $allResults |
    Group-Object -Property Name, DistinguishedName |
    ForEach-Object { $_.Group | Select-Object -First 1 }

# ── OUTPUT ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Engine Status ===" -ForegroundColor Cyan
$engStatus.GetEnumerator() | ForEach-Object {
    Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor $(if ($_.Value -like 'Success*') { 'Green' } else { 'Red' })
}
Write-Host ""
Write-Host "=== CHECK_ID: $($uniqueResults.Count) unique trustees found ===" -ForegroundColor Cyan
$uniqueResults | Format-List

$csvPath = Join-Path $env:TEMP "CHECK_ID_results.csv"
$uniqueResults | Select-Object Name, DistinguishedName, SamAccountName, Domain, Engine |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "Results exported: $csvPath" -ForegroundColor Green
#>


# ============================================================
# KIRO EXECUTION INSTRUCTIONS
# ============================================================
#
# 1. Read these instructions fully before creating any file.
#
# 2. Create the category folder:
#    {SuiteRoot}\ACL_Permissions\
#    DO NOT touch any other existing folder.
#
# 3. For each of the 20 checks (ACL-001 through ACL-020):
#    a. Create subfolder: ACL-XXX_{Sanitized_Check_Name}\
#       (replace spaces with _, remove special chars except hyphens)
#    b. Write all 5 engine files using the templates above
#    c. Run PS parse validation on every .ps1 before finalizing:
#       $e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$null,[ref]$e); $e.Count
#       If $e.Count -gt 0: fix and re-validate. Never write a file with parse errors.
#
# 4. For Pattern A checks (ACL-001 to ACL-014):
#    - Use PATTERN A templates for adsi.ps1, powershell.ps1, combined_multiengine.ps1
#    - Use PATTERN A C# template for csharp.cs
#    - Use the CMD template (informational echo only)
#
# 5. For Pattern B checks (ACL-015 to ACL-020):
#    - Modify templates to use scan-loop approach
#    - $searcher.SecurityMasks = [System.DirectoryServices.SecurityMasks]::Dacl
#    - Loop through scanResults and call GetDirectoryEntry() per object
#    - Same CMD template (informational only)
#
# 6. ACE_CONDITION substitution — use EXACT expressions from the
#    "ACE DETECTION CONDITIONS" section above. Do not improvise.
#
# 7. TARGET_DN_EXPR substitution per check — as specified in each check spec above.
#
# 8. The ACL-005 DCSync check must check BOTH GUIDs:
#    DS-Replication-Get-Changes-All:  1131f6ad-9c07-11d1-f79f-00c04fc2dcd2
#    DS-Replication-Get-Changes:      1131f6aa-9c07-11d1-f79f-00c04fc2dcd2
#    Run GetAccessRules twice (or filter for either GUID) and report each separately.
#
# 9. For the C# combined engine ACE_CONDITION_CS_INLINE:
#    Replace with the actual C# boolean expression (see C# notes in csharp.cs template).
#    This string is injected via StringBuilder.AppendLine() so it is pre-expanded.
#
# 10. NEVER use empty catch { } blocks. All catches must call Write-Warning.
#
# 11. The BH export's TrusteeSID LDAP binding uses:
#     [ADSI]"LDAP://<SID=S-1-5-21-...>"
#     This is ADSI SID binding syntax — works for objects in the current domain.
#     Wrap in try/catch as cross-domain SIDs will fail the bind.
#
# 12. After all 100 files are created, run the post-build count check:
#     $count = (Get-ChildItem "{SuiteRoot}\ACL_Permissions" -Recurse -Filter "*.ps1").Count +
#              (Get-ChildItem "{SuiteRoot}\ACL_Permissions" -Recurse -Filter "*.cs").Count +
#              (Get-ChildItem "{SuiteRoot}\ACL_Permissions" -Recurse -Filter "*.bat").Count
#     Expected: 100 (20 checks × 5 engines — 20 adsi.ps1 + 20 powershell.ps1 +
#                    20 combined_multiengine.ps1 + 20 csharp.cs + 20 cmd.bat)
#
# 13. DO NOT modify any existing script outside ACL_Permissions\.
#     If you find yourself editing any other file, STOP immediately.
# ============================================================


# ============================================================
# QUICK REFERENCE: ACE RIGHTS INTEGER VALUES
# ============================================================
# GenericAll     = 0x10000000 = 268435456
# GenericWrite   = 0x40000000 = 1073741824
# WriteDacl      = 0x00040000 = 262144
# WriteOwner     = 0x00080000 = 524288
# ExtendedRight  = 0x00000100 = 256
# Self           = 0x00000008 = 8
#
# Named rights as ActiveDirectoryRights enum values:
# [System.DirectoryServices.ActiveDirectoryRights]::GenericAll
# [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite
# [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl
# [System.DirectoryServices.ActiveDirectoryRights]::WriteOwner
# [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight
# [System.DirectoryServices.ActiveDirectoryRights]::Self
# ============================================================

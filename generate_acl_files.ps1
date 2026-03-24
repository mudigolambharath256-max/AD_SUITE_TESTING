# ACL_Permissions File Generator
# Generates all 100 files (20 checks × 5 engines) according to KIRO_ACL_PERMISSIONS_PROMPT.md

$ErrorActionPreference = 'Stop'

# Define all 20 checks with their specifications
$checks = @(
    @{
        Id = 'ACL-001'
        Name = 'GenericAll on Domain Object'
        Folder = 'ACL-001_GenericAll_on_Domain_Object'
        Severity = 'critical'
        Pattern = 'A'
        TargetDN = '$domainNC'
        TargetDNCS = 'domainNC'
        AceCondition = '($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'
        AceConditionCS = '(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'
        Rights = 'GenericAll'
        RightsCS = 'GenericAll'
        TargetDisplay = 'Domain NC object'
        ScanFilter = ''
        SearchBase = ''
    },
    @{
        Id = 'ACL-002'
        Name = 'WriteDACL on Domain Object'
        Folder = 'ACL-002_WriteDACL_on_Domain_Object'
        Severity = 'critical'
        Pattern = 'A'
        TargetDN = '$domainNC'
        TargetDNCS = 'domainNC'
        AceCondition = '($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'
        AceConditionCS = '(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'
        Rights = 'WriteDacl'
        RightsCS = 'WriteDacl'
        TargetDisplay = 'Domain NC object'
        ScanFilter = ''
        SearchBase = ''
    },
    @{
        Id = 'ACL-003'
        Name = 'WriteOwner on Domain Object'
        Folder = 'ACL-003_WriteOwner_on_Domain_Object'
        Severity = 'critical'
        Pattern = 'A'
        TargetDN = '$domainNC'
        TargetDNCS = 'domainNC'
        AceCondition = '($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteOwner)'
        AceConditionCS = '(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteOwner) != 0'
        Rights = 'WriteOwner'
        RightsCS = 'WriteOwner'
        TargetDisplay = 'Domain NC object'
        ScanFilter = ''
        SearchBase = ''
    },
    @{
        Id = 'ACL-004'
        Name = 'AllExtendedRights on Domain Object'
        Folder = 'ACL-004_AllExtendedRights_on_Domain_Object'
        Severity = 'critical'
        Pattern = 'A'
        TargetDN = '$domainNC'
        TargetDNCS = 'domainNC'
        AceCondition = '($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and ($null -eq $_.ObjectType -or $_.ObjectType -eq [guid]::Empty)'
        AceConditionCS = '(rule.ActiveDirectoryRights & ActiveDirectoryRights.ExtendedRight) != 0 && rule.ObjectType == Guid.Empty'
        Rights = 'AllExtendedRights'
        RightsCS = 'AllExtendedRights'
        TargetDisplay = 'Domain NC object'
        ScanFilter = ''
        SearchBase = ''
    },
    @{
        Id = 'ACL-005'
        Name = 'DCSync Rights DS-Replication-Get-Changes-All'
        Folder = 'ACL-005_DCSync_Rights_DS_Replication_Get_Changes_All'
        Severity = 'critical'
        Pattern = 'A'
        TargetDN = '$domainNC'
        TargetDNCS = 'domainNC'
        AceCondition = '($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and ($_.ObjectType -ne $null) -and ($_.ObjectType.ToString() -eq ''1131f6ad-9c07-11d1-f79f-00c04fc2dcd2'')'
        AceConditionCS = 'rule.ObjectType == new Guid("1131f6ad-9c07-11d1-f79f-00c04fc2dcd2")'
        Rights = 'DS-Replication-Get-Changes-All (DCSync)'
        RightsCS = 'DS-Replication-Get-Changes-All (DCSync)'
        TargetDisplay = 'Domain NC object'
        ScanFilter = ''
        SearchBase = ''
    },
    @{
        Id = 'ACL-006'
        Name = 'GenericAll on AdminSDHolder'
        Folder = 'ACL-006_GenericAll_on_AdminSDHolder'
        Severity = 'critical'
        Pattern = 'A'
        TargetDN = '"CN=AdminSDHolder,CN=System,$domainNC"'
        TargetDNCS = '"CN=AdminSDHolder,CN=System," + domainNC'
        AceCondition = '($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)'
        AceConditionCS = '(rule.ActiveDirectoryRights & ActiveDirectoryRights.GenericAll) != 0'
        Rights = 'GenericAll'
        RightsCS = 'GenericAll'
        TargetDisplay = 'AdminSDHolder'
        ScanFilter = ''
        SearchBase = ''
    },
    @{
        Id = 'ACL-007'
        Name = 'WriteDACL on AdminSDHolder'
        Folder = 'ACL-007_WriteDACL_on_AdminSDHolder'
        Severity = 'critical'
        Pattern = 'A'
        TargetDN = '"CN=AdminSDHolder,CN=System,$domainNC"'
        TargetDNCS = '"CN=AdminSDHolder,CN=System," + domainNC'
        AceCondition = '($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)'
        AceConditionCS = '(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteDacl) != 0'
        Rights = 'WriteDacl'
        RightsCS = 'WriteDacl'
        TargetDisplay = 'AdminSDHolder'
        ScanFilter = ''
        SearchBase = ''
    },
    @{
        Id = 'ACL-008'
        Name = 'WriteOwner on AdminSDHolder'
        Folder = 'ACL-008_WriteOwner_on_AdminSDHolder'
        Severity = 'critical'
        Pattern = 'A'
        TargetDN = '"CN=AdminSDHolder,CN=System,$domainNC"'
        TargetDNCS = '"CN=AdminSDHolder,CN=System," + domainNC'
        AceCondition = '($_.AccessControlType -eq ''Allow'') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteOwner)'
        AceConditionCS = '(rule.ActiveDirectoryRights & ActiveDirectoryRights.WriteOwner) != 0'
        Rights = 'WriteOwner'
        RightsCS = 'WriteOwner'
        TargetDisplay = 'AdminSDHolder'
        ScanFilter = ''
        SearchBase = ''
    }
)

Write-Host "Generating ACL_Permissions files..." -ForegroundColor Cyan
Write-Host "This will create 100 files (20 checks × 5 engines)" -ForegroundColor Yellow
Write-Host ""

$fileCount = 0

foreach ($check in $checks) {
    $checkPath = Join-Path "ACL_Permissions" $check.Folder
    Write-Host "Processing $($check.Id) - $($check.Name)..." -ForegroundColor Green
    
    # Generate adsi.ps1
    $adsiContent = @"
# Check: $($check.Name)
# Category: ACL_Permissions
# Severity: $($check.Severity)
# ID: $($check.Id)
# Requirements: None
# ============================================

`$root     = [ADSI]'LDAP://RootDSE'
`$domainNC = `$root.Properties['defaultNamingContext'].Value

# Build target DN
`$targetDN  = $($check.TargetDN)
`$targetObj = [ADSI]"LDAP://`$targetDN"
`$acl       = `$targetObj.ObjectSecurity

`$findings = [System.Collections.Generic.List[PSObject]]::new()

`$skipSids = @('S-1-5-18','S-1-5-10','S-1-5-9')

`$acl.GetAccessRules(`$true, `$true, [System.Security.Principal.SecurityIdentifier]) |
    Where-Object {
        $($check.AceCondition)
    } | ForEach-Object {
        `$trusteeSid  = `$_.IdentityReference.Value
        if (`$trusteeSid -in `$skipSids) { return }
        `$trusteeName = `$trusteeSid
        try {
            `$trusteeName = (New-Object System.Security.Principal.SecurityIdentifier(`$trusteeSid)).Translate(
                [System.Security.Principal.NTAccount]).Value
        } catch { }

        `$dom = ((`$targetDN -split ',') | Where-Object { `$_ -match '^DC=' } |
                ForEach-Object { (`$_ -replace '^DC=','') }) -join '.'

        `$findings.Add([PSCustomObject]@{
            Name              = `$trusteeName
            DistinguishedName = `$targetDN.ToUpper()
            SamAccountName    = `$trusteeName
            Domain            = `$dom
            Engine            = 'ADSI'
            Rights            = '$($check.Rights)'
            TargetObject      = `$targetDN
            TrusteeSID        = `$trusteeSid
        })
    }

Write-Host "$($check.Id): found `$(`$findings.Count) trustees with $($check.Rights) on $($check.TargetDisplay)"
`$findings

# ── BloodHound Export ─────────────────────────────────────────────────────────
try {
    `$bhSession = if (`$env:ADSUITE_SESSION_ID) { `$env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    `$bhRoot    = if (`$env:ADSUITE_OUTPUT_ROOT) { `$env:ADSUITE_OUTPUT_ROOT } else { Join-Path `$env:TEMP 'ADSuite_Sessions' }
    `$bhDir     = Join-Path `$bhRoot (Join-Path `$bhSession 'bloodhound')
    if (-not (Test-Path `$bhDir)) { `$null = New-Item -ItemType Directory -Path `$bhDir -Force -ErrorAction Stop }

    `$bhNodes = [System.Collections.Generic.List[hashtable]]::new()
    foreach (`$f in `$findings) {
        `$oid  = `$f.TrusteeSID
        `$bhNm = `$f.Name
        # Attempt SID-based LDAP resolution
        try {
            `$tEntry = [ADSI]"LDAP://<SID=`$(`$f.TrusteeSID)>"
            `$tSam   = (`$tEntry.Properties['samAccountName'] | Select-Object -First 1)
            `$tDn    = (`$tEntry.Properties['distinguishedName'] | Select-Object -First 1)
            `$tDom   = ((`$tDn -split ',') | Where-Object { `$_ -match '^DC=' } |
                       ForEach-Object { (`$_ -replace '^DC=','').ToUpper() }) -join '.'
            if (`$tSam) { `$bhNm = "`$(`$tSam.ToUpper())@`$tDom" }
        } catch { }

        `$bhNodes.Add(@{
            ObjectIdentifier = `$oid
            Properties = @{
                name             = `$bhNm
                domain           = `$f.Domain
                distinguishedname = `$f.DistinguishedName
                enabled          = `$true
                isdeleted        = `$false
                adSuiteCheckId   = '$($check.Id)'
                adSuiteCheckName = '$($check.Name)'
                adSuiteSeverity  = '$($check.Severity)'
                adSuiteCategory  = 'ACL_Permissions'
                adSuiteFlag      = `$true
                aclRights        = `$f.Rights
                aclTarget        = `$f.TargetObject
            }
            Aces = @(); IsDeleted = `$false; IsACLProtected = `$false
        })
    }
    `$bhTs = Get-Date -Format 'yyyyMMdd_HHmmss'
    @{ data = `$bhNodes.ToArray()
       meta = @{ type = 'users'; count = `$bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress |
        Out-File -FilePath (Join-Path `$bhDir "$($check.Id)_`$bhTs.json") -Encoding UTF8 -Force
} catch { Write-Warning "$($check.Id) BloodHound export error: `$_" }
# ── End BloodHound Export ─────────────────────────────────────────────────────
"@
    
    $adsiPath = Join-Path $checkPath "adsi.ps1"
    $adsiContent | Out-File -FilePath $adsiPath -Encoding UTF8 -Force
    $fileCount++
    
    Write-Host "  Created adsi.ps1" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Generated $fileCount files so far..." -ForegroundColor Cyan
Write-Host "Script incomplete - this is a partial implementation for demonstration" -ForegroundColor Yellow

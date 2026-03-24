# Check: GenericAll on Domain Admins
# Category: ACL_Permissions
# Severity: critical
# ID: ACL-009
# Requirements: None
# ============================================

$root     = [ADSI]'LDAP://RootDSE'
$domainNC = $root.Properties['defaultNamingContext'].Value
$daSearcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$domainNC")
$daSearcher.Filter = '(&(objectCategory=group)(cn=Domain Admins))'
$daSearcher.PropertiesToLoad.Add('distinguishedName') | Out-Null
$daResult = $daSearcher.FindOne()
$targetDN = if ($daResult) { $daResult.Properties['distinguishedname'][0] } else { "CN=Domain Admins,CN=Users,$domainNC" }
$targetObj = [ADSI]"LDAP://$targetDN"
$acl       = $targetObj.ObjectSecurity

$findings = [System.Collections.Generic.List[PSObject]]::new()

$skipSids = @('S-1-5-18','S-1-5-10','S-1-5-9')

$acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]) |
    Where-Object {
        ($_.AccessControlType -eq 'Allow') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)
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
            Rights            = 'GenericAll'
            TargetObject      = $targetDN
            TrusteeSID        = $trusteeSid
        })
    }

Write-Host "ACL-009: found $($findings.Count) trustees with GenericAll"
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
                adSuiteCheckId   = 'ACL-009'
                adSuiteCheckName = 'GenericAll on Domain Admins'
                adSuiteSeverity  = 'critical'
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
        Out-File -FilePath (Join-Path $bhDir "ACL-009_$bhTs.json") -Encoding UTF8 -Force
} catch { Write-Warning "ACL-009 BloodHound export error: $_" }
# ── End BloodHound Export ─────────────────────────────────────────────────────

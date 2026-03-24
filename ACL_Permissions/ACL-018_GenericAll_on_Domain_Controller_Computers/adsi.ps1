# Check: GenericAll on Domain Controller Computers
# Category: ACL_Permissions
# Severity: critical
# ID: ACL-018
# Requirements: None
# ============================================

$root     = [ADSI]'LDAP://RootDSE'
$domainNC = $root.Properties['defaultNamingContext'].Value
$searcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$domainNC")
$searcher.Filter = '(&(objectCategory=computer)(primaryGroupID=516))'
$searcher.SecurityMasks = [System.DirectoryServices.SecurityMasks]::Dacl
$searcher.PropertiesToLoad.Add('distinguishedName') | Out-Null
$searcher.PropertiesToLoad.Add('name') | Out-Null
$searcher.PropertiesToLoad.Add('samAccountName') | Out-Null

$findings = [System.Collections.Generic.List[PSObject]]::new()
$skipSids = @('S-1-5-18','S-1-5-10','S-1-5-9')

$scanResults = $searcher.FindAll()
foreach ($sr in $scanResults) {
    $entry = $sr.GetDirectoryEntry()
    $acl = $entry.ObjectSecurity
    $targetDN = ($sr.Properties['distinguishedname'] | Select-Object -First 1)
    
    $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]) |
        Where-Object {
            ($_.AccessControlType -eq 'Allow') -and ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)
        } |
        ForEach-Object {
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
}

Write-Host "ACL-018: found $($findings.Count) trustees with GenericAll"
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
                adSuiteCheckId   = 'ACL-018'
                adSuiteCheckName = 'GenericAll on Domain Controller Computers'
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
        Out-File -FilePath (Join-Path $bhDir "ACL-018_$bhTs.json") -Encoding UTF8 -Force
} catch { Write-Warning "ACL-018 BloodHound export error: $_" }
# ── End BloodHound Export ─────────────────────────────────────────────────────

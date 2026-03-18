# Check: Access Control Check 32
# Category: Access Control
# Severity: medium
# ID: ACC-032
# Requirements: None
# ============================================

# Fix R11: Conditional NC declarations - only what this partition needs
$root     = [ADSI]'LDAP://RootDSE'
$domainNC = $root.Properties['defaultNamingContext'].Value

# Fix R01: SearchRoot explicitly bound to correct partition
$searchBase = [ADSI]"LDAP://$domainNC"
$searcher   = New-Object System.DirectoryServices.DirectorySearcher($searchBase)
$searcher.Filter   = '(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
# Fix R12: objectSid only for identity objects
@('name','distinguishedName','samAccountName', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

$results = $searcher.FindAll()
Write-Host "ACC-032: found $($results.Count) objects"

# Fix R07: Standard 5-field output schema + Fix R13: check-specific extra fields
$output = @()
$results | ForEach-Object {
    $p   = $_.Properties
    $dn  = ($p['distinguishedname'] | Select-Object -First 1)
    $sam = ($p['samaccountname']    | Select-Object -First 1)
    $name = ($p['name']             | Select-Object -First 1)
    $cn  = ($p['cn']                | Select-Object -First 1)
    
    # Extract domain from DN
    $domain = if ($dn) { 
        (($dn -split ',') | Where-Object { $_ -match '^DC=' } | ForEach-Object { ($_ -replace '^DC=','') }) -join '.'
    } else { '' }
    
    # Fix R07: Standardized 5-field output schema
    $obj = [PSCustomObject]@{
        Name              = if ($sam) { $sam } elseif ($cn) { $cn } else { $name }
        DistinguishedName = [string]$dn.ToUpper()  # Fix R09: DN normalization
        SamAccountName    = [string]$sam
        Domain            = $domain
        Engine            = 'ADSI'
    }
    
    # Fix R13: Add relevant detection data to output

    
    $output += $obj
}

$output | Format-List
$results.Dispose()

# ── Fixed BloodHound Export ─────────────────────────────────────────────────────
try {
    $bhSession = if ($env:ADSUITE_SESSION_ID) { $env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    $bhRoot    = if ($env:ADSUITE_OUTPUT_ROOT) { $env:ADSUITE_OUTPUT_ROOT } else { Join-Path $env:TEMP 'ADSuite_Sessions' }
    $bhDir     = Join-Path $bhRoot (Join-Path $bhSession 'bloodhound')
    if (-not (Test-Path $bhDir)) { New-Item -ItemType Directory -Path $bhDir -Force -ErrorAction Stop | Out-Null }

    # Fix R12: Separate BH query with minimal required props
    $bhS = New-Object System.DirectoryServices.DirectorySearcher($searchBase)
    $bhS.Filter   = '(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))'
    $bhS.PageSize = 1000
    $bhS.PropertiesToLoad.Clear()
    @('name','distinguishedname','samaccountname','cn','displayname','objectsid','useraccountcontrol') |
        Where-Object { $_ } | ForEach-Object { [void]$bhS.PropertiesToLoad.Add($_) }
    $bhRaw   = $bhS.FindAll()
    $bhNodes = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($r in $bhRaw) {
        $p   = $r.Properties
        $dn  = ($p['distinguishedname'] | Select-Object -First 1)
        $nm  = ($p['name']              | Select-Object -First 1)
        $sam = ($p['samaccountname']    | Select-Object -First 1)
        $cn  = ($p['cn']                | Select-Object -First 1)
        $dsp = ($p['displayname']       | Select-Object -First 1)
        $dom = (($dn -split ',') | Where-Object { $_ -match '^DC=' } |
                 ForEach-Object { ($_ -replace '^DC=','').ToUpper() }) -join '.'

        # Fix R06: BH identity uses the correct primary attribute per node type
        $bhName = if ($sam) { "$($sam.ToUpper())@$dom" } else { "$($nm.ToUpper())@$dom" }

        # Fix R06: ObjectIdentifier — prefer SID for identity objects
        $oid = if ($dn) { $dn.ToUpper() } else { [guid]::NewGuid().ToString() }
        $sid = if ($p['objectsid'].Count -gt 0) { $p['objectsid'][0] } else { $null }
        if ($sid) { try { $oid = (New-Object System.Security.Principal.SecurityIdentifier([byte[]]$sid, 0)).Value } catch { } }

        $bhNodes.Add(@{
            ObjectIdentifier = $oid
            Properties       = @{
                name              = $bhName
                domain            = $dom
                distinguishedname = [string]$dn
                samaccountname    = [string]$sam
                enabled           = -not (([int]($p['useraccountcontrol'] | Select-Object -First 1)) -band 2)
                isdeleted         = $false
                adSuiteCheckId    = 'ACC-032'
                adSuiteCheckName  = 'Access Control Check 32'
                adSuiteSeverity   = 'medium'
                adSuiteCategory   = 'Access_Control'
                adSuiteFlag       = $true
            }
            Aces           = @()
            IsDeleted      = $false
            IsACLProtected = $false
        })
    }
    $bhRaw.Dispose()

    $bhTs = Get-Date -Format 'yyyyMMdd_HHmmss'
    @{ data = $bhNodes.ToArray()
       meta = @{ type = 'users'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress |
        Out-File -FilePath (Join-Path $bhDir "ACC-032_$bhTs.json") -Encoding UTF8 -Force

# Fix R10: No silent catch — warn on failure
} catch { Write-Warning "ACC-032 BloodHound export error: $_" }
# ── End BloodHound Export ─────────────────────────────────────────────────────

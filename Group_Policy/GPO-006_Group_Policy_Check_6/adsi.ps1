# Check: Group Policy Check 6
# Category: Group Policy
# Severity: medium
# ID: GPO-006
# Requirements: None
# ============================================

# Fix R11: Conditional NC declarations - only what this partition needs
$root     = [ADSI]'LDAP://RootDSE'
$domainNC = $root.Properties['defaultNamingContext'].Value

# Fix R01: SearchRoot explicitly bound to correct partition
$searchBase = [ADSI]"LDAP://CN=Policies,CN=System,$domainNC"
$searcher   = New-Object System.DirectoryServices.DirectorySearcher($searchBase)
$searcher.Filter   = '(&(objectClass=groupPolicyContainer))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
# Fix R12: objectSid only for identity objects
@('name','distinguishedName','displayName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

$results = $searcher.FindAll()
Write-Host "GPO-006: found $($results.Count) objects"

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
        displayName = ($p['displayname'] | Select-Object -First 1)
    
    $output += $obj
}

$output
$results.Dispose()

# ── Fixed BloodHound Export ─────────────────────────────────────────────────────
try {
    $bhSession = if ($env:ADSUITE_SESSION_ID) { $env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    $bhRoot    = if ($env:ADSUITE_OUTPUT_ROOT) { $env:ADSUITE_OUTPUT_ROOT } else { Join-Path $env:TEMP 'ADSuite_Sessions' }
    $bhDir     = Join-Path $bhRoot (Join-Path $bhSession 'bloodhound')
    if (-not (Test-Path $bhDir)) { New-Item -ItemType Directory -Path $bhDir -Force -ErrorAction Stop | Out-Null }

    # Fix R12: Separate BH query with minimal required props
    $bhS = New-Object System.DirectoryServices.DirectorySearcher($searchBase)
    $bhS.Filter   = '(&(objectClass=groupPolicyContainer))'
    $bhS.PageSize = 1000
    $bhS.PropertiesToLoad.Clear()
    @('name','distinguishedname','samaccountname','cn','displayname') |
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
        $bhName = if ($dsp) { $dsp } else { $nm }

        # Fix R06: ObjectIdentifier — prefer SID for identity objects
        $oid = if ($dn) { $dn.ToUpper() } else { [guid]::NewGuid().ToString() }


        $bhNodes.Add(@{
            ObjectIdentifier = $oid
            Properties       = @{
                name              = $bhName
                domain            = $dom
                distinguishedname = [string]$dn
                samaccountname    = [string]$sam
                enabled           = $true
                isdeleted         = $false
                adSuiteCheckId    = 'GPO-006'
                adSuiteCheckName  = 'Group Policy Check 6'
                adSuiteSeverity   = 'medium'
                adSuiteCategory   = 'Group_Policy'
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
       meta = @{ type = 'gpos'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress |
        Out-File -FilePath (Join-Path $bhDir "GPO-006_$bhTs.json") -Encoding UTF8 -Force

# Fix R10: No silent catch — warn on failure
} catch { Write-Warning "GPO-006 BloodHound export error: $_" }
# ── End BloodHound Export ─────────────────────────────────────────────────────

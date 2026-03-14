# ============================================================================
# INFRA-032: Wildcard DNS Records
# ============================================================================
# Multi-Engine Implementation
# ============================================================================

[CmdletBinding()]
param([Parameter()][string]$SearchBase, [Parameter()][string]$ExportPath)

Write-Host "=== INFRA-032: Wildcard DNS Records ===" -ForegroundColor Cyan

$useADModule = $false
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $useADModule = $true
    Write-Host "[Method] PowerShell AD Module" -ForegroundColor Green
} catch {
    Write-Host "[Method] ADSI Fallback" -ForegroundColor Yellow
}

if ($useADModule) {
    $domain = Get-ADDomain
    if (-not $SearchBase) { $SearchBase = $domain.DistinguishedName }
    $results = Get-ADObject -LDAPFilter '(objectClass=dnsNode)' -Properties name,distinguishedName -SearchBase $SearchBase -SearchScope Subtree -ResultSetSize $null
} else {
    $root = [ADSI]'LDAP://RootDSE'
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://$($root.defaultNamingContext)"
    $searcher.Filter = '(objectClass=dnsNode)'
    $searcher.PageSize = 1000
    $results = $searcher.FindAll()
    $searcher.Dispose()
}

Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan
return $results

# ── BloodHound Export ─────────────────────────────────────────────────────────
# Added by Kiro automation — DO NOT modify lines above this section
try {
    $bhSession = if ($env:ADSUITE_SESSION_ID) { $env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    $bhRoot    = if ($env:ADSUITE_OUTPUT_ROOT) { $env:ADSUITE_OUTPUT_ROOT } else { Join-Path $env:TEMP 'ADSuite_Sessions' }
    $bhDir     = Join-Path $bhRoot "$bhSession\bloodhound"
    if (-not (Test-Path $bhDir)) { New-Item -ItemType Directory -Path $bhDir -Force -ErrorAction Stop | Out-Null }

    $bhNodes = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($r in $uniqueResults) {
        $dn   = if ($r.DistinguishedName) { $r.DistinguishedName } else { '' }
        $name = if ($r.Name) { $r.Name } else { if ($r.PSObject.Properties['CheckName']) { $r.CheckName } else { 'UNKNOWN' } }
        $dom  = (($dn -split ',') | Where-Object{$_ -match '^DC='} | ForEach-Object{$_ -replace '^DC=',''}) -join '.' | ForEach-Object{$_.ToUpper()}
        $oid  = if ($dn) { $dn.ToUpper() } else { [guid]::NewGuid().ToString() }

        $bhNodes.Add(@{
            ObjectIdentifier = $oid
            Properties       = @{
                name              = if ($dom) { "$($name.ToUpper())@$dom" } else { $name.ToUpper() }
                domain            = $dom
                distinguishedname = $dn.ToUpper()
                enabled           = $true
                adSuiteCheckId    = 'INFRA-032'
                adSuiteCheckName  = 'Wildcard_DNS_Records'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteInfrastructure   = 'Infrastructure'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "INFRA-032_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

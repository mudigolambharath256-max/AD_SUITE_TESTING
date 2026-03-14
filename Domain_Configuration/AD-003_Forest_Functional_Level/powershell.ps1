# ============================================================
# CHECK: AD-003_Forest_Functional_Level
# CATEGORY: Domain_Configuration
# DESCRIPTION: Checks forest functional level for security features
# LDAP FILTER: (objectClass=crossRefContainer)
# SEARCH BASE: CN=Partitions,CN=Configuration,<ForestDN>
# OBJECT CLASS: crossRefContainer
# ATTRIBUTES: msDS-Behavior-Version, distinguishedName
# RISK: MEDIUM
# MITRE ATT&CK: T1484 (Domain Policy Modification)
# ============================================================

# PowerShell Active Directory Module Implementation
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : Active Directory
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    # Get forest functional level
    $forest = Get-ADForest -Current LocalComputer
    $functionalLevel = $forest.ForestMode

    # Map functional level to numeric value for consistency
    $levelMap = @{
        'Windows2000Forest' = 0
        'Windows2003InterimForest' = 1
        'Windows2003Forest' = 2
        'Windows2008Forest' = 3
        'Windows2008R2Forest' = 4
        'Windows2012Forest' = 5
        'Windows2012R2Forest' = 6
        'Windows2016Forest' = 7
        'Windows2019Forest' = 10
        'Windows2022Forest' = 10
    }

    $numericLevel = if ($levelMap.ContainsKey($functionalLevel)) { $levelMap[$functionalLevel] } else { -1 }
    $severity = if ($numericLevel -lt 7) { "HIGH" } else { "MEDIUM" }

    $output = [PSCustomObject]@{
        CheckID = 'AD-003'
        CheckName = 'Forest Functional Level'
        Domain = $forest.Name
        ObjectDN = "CN=Partitions,CN=Configuration,$($forest.PartitionsContainer)"
        ObjectName = 'Forest Root'
        FindingDetail = "Forest functional level: $numericLevel ($functionalLevel)"
        Severity = $severity
        Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
    }

    Write-Host "Found forest functional level: $functionalLevel" -ForegroundColor Cyan
    $output | Format-Table -AutoSize

} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
# ── BloodHound Export ─────────────────────────────────────────────────────────
# Added by Kiro automation — DO NOT modify lines above this section
try {
    $bhSession = if ($env:ADSUITE_SESSION_ID) { $env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    $bhRoot    = if ($env:ADSUITE_OUTPUT_ROOT) { $env:ADSUITE_OUTPUT_ROOT } else { Join-Path $env:TEMP 'ADSuite_Sessions' }
    $bhDir     = Join-Path $bhRoot "$bhSession\bloodhound"
    if (-not (Test-Path $bhDir)) { New-Item -ItemType Directory -Path $bhDir -Force -ErrorAction Stop | Out-Null }

    $bhNodes = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($r in $output) {
        $dn   = if ($r.DistinguishedName) { $r.DistinguishedName } else { '' }
        $name = if ($r.Name) { $r.Name } else { 'UNKNOWN' }
        $dom  = (($dn -split ',') | Where-Object{$_ -match '^DC='} | ForEach-Object{$_ -replace '^DC=',''}) -join '.' | ForEach-Object{$_.ToUpper()}
        $oid  = if ($dn) { $dn.ToUpper() } else { [guid]::NewGuid().ToString() }

        $bhNodes.Add(@{
            ObjectIdentifier = $oid
            Properties       = @{
                name              = if ($dom) { "$($name.ToUpper())@$dom" } else { $name.ToUpper() }
                domain            = $dom
                distinguishedname = $dn.ToUpper()
                enabled           = $true
                adSuiteCheckId    = 'AD-003'
                adSuiteCheckName  = 'Forest_Functional_Level'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteDomain_Configuration   = 'Domain_Configuration'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "AD-003_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

# ============================================================
# CHECK: AD-002_Domain_Functional_Level
# CATEGORY: Domain_Configuration
# DESCRIPTION: Checks domain functional level for security features
# LDAP FILTER: (objectClass=domainDNS)
# SEARCH BASE: Default NC (Base scope on domain root)
# OBJECT CLASS: domainDNS
# ATTRIBUTES: msDS-Behavior-Version, distinguishedName, name
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

    # Get domain functional level
    $domain = Get-ADDomain -Current LocalComputer
    $functionalLevel = $domain.DomainMode

    # Map functional level to numeric value for consistency
    $levelMap = @{
        'Windows2000Domain' = 0
        'Windows2003InterimDomain' = 1
        'Windows2003Domain' = 2
        'Windows2008Domain' = 3
        'Windows2008R2Domain' = 4
        'Windows2012Domain' = 5
        'Windows2012R2Domain' = 6
        'Windows2016Domain' = 7
        'Windows2019Domain' = 10
        'Windows2022Domain' = 10
    }

    $numericLevel = if ($levelMap.ContainsKey($functionalLevel)) { $levelMap[$functionalLevel] } else { -1 }
    $severity = if ($numericLevel -lt 7) { "HIGH" } else { "MEDIUM" }

    $output = [PSCustomObject]@{
        CheckID = 'AD-002'
        CheckName = 'Domain Functional Level'
        Domain = $domain.DNSRoot
        ObjectDN = $domain.DistinguishedName
        ObjectName = $domain.Name
        FindingDetail = "Domain functional level: $numericLevel ($functionalLevel)"
        Severity = $severity
        Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
    }

    Write-Host "Found domain functional level: $functionalLevel" -ForegroundColor Cyan
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
                adSuiteCheckId    = 'AD-002'
                adSuiteCheckName  = 'Domain_Functional_Level'
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
    $bhFile = Join-Path $bhDir "AD-002_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

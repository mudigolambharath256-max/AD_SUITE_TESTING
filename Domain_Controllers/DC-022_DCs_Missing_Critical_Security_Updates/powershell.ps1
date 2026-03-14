# Check: DCs Missing Critical Security Updates
# Category: Domain Controllers
# Severity: critical
# ID: DC-046
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
$props = @('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'objectSid')

$dcs = Get-ADObject -LDAPFilter $ldapFilter -SearchBase $searchBase -Properties $props -ErrorAction Stop

foreach ($dc in $dcs) {
  try {
    $searchBase = (Get-ADRootDSE).defaultNamingContext

    # Check for missing updates using Windows Update COM object
    $session = [activator]::CreateInstance([type]::GetTypeFromProgID("Microsoft.Update.Session", $dc.dNSHostName))
    $searcher = $session.CreateUpdateSearcher()

    # Search for updates that are not installed
    $searchResult = $searcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")

    $criticalUpdates = @()
    $importantUpdates = @()

    foreach ($update in $searchResult.Updates) {
      if ($update.MsrcSeverity -eq "Critical") {
        $criticalUpdates += $update.Title
      } elseif ($update.MsrcSeverity -eq "Important") {
        $importantUpdates += $update.Title
      }
    }

    if ($criticalUpdates.Count -gt 0 -or $importantUpdates.Count -gt 0) {
      [PSCustomObject]@{
        Name = $dc.name
        DistinguishedName = $dc.distinguishedName
        DNSHostName = $dc.dNSHostName
        OperatingSystem = $dc.operatingSystem
        CriticalUpdatesCount = $criticalUpdates.Count
        ImportantUpdatesCount = $importantUpdates.Count
        TotalMissingUpdates = $searchResult.Updates.Count
        CriticalUpdatesList = ($criticalUpdates | Select-Object -First 5) -join "; "
        LastChecked = Get-Date
      }
    }
  } catch {
    Write-Warning "Unable to check updates on $($dc.dNSHostName): $_"
  }
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
                adSuiteCheckId    = 'DC-022'
                adSuiteCheckName  = 'DCs_Missing_Critical_Security_Updates'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteDomain_Controllers   = 'Domain_Controllers'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "DC-022_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

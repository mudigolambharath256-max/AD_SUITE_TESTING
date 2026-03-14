# Check: DCs Replication Failures
# Category: Domain Controllers
# Severity: high
# ID: DC-037
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
$props = @('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'whenChanged', 'objectSid')

$dcs = Get-ADObject -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop
$staleThreshold = (Get-Date).AddHours(-24)

foreach ($dc in $dcs) {
  try {
    # Check replication status using Get-ADReplicationPartnerMetadata
    $replStatus = Get-ADReplicationPartnerMetadata -Target $dc.dNSHostName -ErrorAction Stop

    $hasFailures = $false
    $failureDetails = @()

    foreach ($partner in $replStatus) {
      if ($partner.LastReplicationResult -ne 0 -or $partner.LastReplicationAttempt -lt $staleThreshold) {
        $hasFailures = $true
        $failureDetails += "$($partner.Partner): Error $($partner.LastReplicationResult), Last: $($partner.LastReplicationAttempt)"
      }
    }

    if ($hasFailures) {
      [PSCustomObject]@{
        Name = $dc.name
        DistinguishedName = $dc.distinguishedName
        DNSHostName = $dc.dNSHostName
        OperatingSystem = $dc.operatingSystem
        WhenChanged = $dc.whenChanged
        ReplicationIssues = $failureDetails -join "; "
      }
    }
  } catch {
    Write-Warning "Unable to check replication on $($dc.dNSHostName): $_"
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
                adSuiteCheckId    = 'DC-037'
                adSuiteCheckName  = 'DCs_Replication_Failures'
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
    $bhFile = Join-Path $bhDir "DC-037_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

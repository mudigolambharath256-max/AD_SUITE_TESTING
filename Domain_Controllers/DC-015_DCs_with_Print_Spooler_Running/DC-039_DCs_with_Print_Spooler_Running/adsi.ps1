# Check: DCs with Print Spooler Running
# Category: Domain Controllers
# Severity: critical
# ID: DC-039
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

$searcher = [ADSISearcher]'(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

$results = $searcher.FindAll()
Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan

$output = $results | ForEach-Object {
  $p = $_.Properties
  $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

  try {
    $spoolerService = Get-Service -Name Spooler -ComputerName $dnsHostName -ErrorAction Stop
    if ($spoolerService.Status -eq 'Running') {
      [PSCustomObject]@{
        Label = 'DCs with Print Spooler Running'
        Name = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0]
        UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
    UserAccountControl = if ($p['useraccountcontrol'] -and $p['useraccountcontrol'].Count -gt 0) { $p['useraccountcontrol'][0] } else { 'N/A' } } else { 'N/A' } } else { 'N/A' }
        DistinguishedName = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
        DNSHostName = $dnsHostName
        OperatingSystem = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
        SpoolerStatus = $spoolerService.Status
        SpoolerStartType = $spoolerService.StartType
      }
    }
  } catch {
    Write-Warning "Unable to check Print Spooler on ${dnsHostName}: $_"
  }
}

$results.Dispose()
$searcher.Dispose()

if ($output) { $output | Format-Table -AutoSize }
else { Write-Host 'No findings' -ForegroundColor Gray }


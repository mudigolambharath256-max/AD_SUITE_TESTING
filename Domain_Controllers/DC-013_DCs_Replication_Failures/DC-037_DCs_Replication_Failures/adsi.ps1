# Check: DCs Replication Failures
# Category: Domain Controllers
# Severity: high
# ID: DC-037
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $searcher = [ADSISearcher]'(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $searcher.PageSize = 1000
    $searcher.PropertiesToLoad.Clear()
    (@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'whenChanged', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan

    $output = $results | ForEach-Object {
      $p = $_.Properties
      [PSCustomObject]@{
        Label = 'DCs Replication Failures'
        Name = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0]
        UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
    UserAccountControl = if ($p['useraccountcontrol'] -and $p['useraccountcontrol'].Count -gt 0) { $p['useraccountcontrol'][0] } else { 'N/A' } } else { 'N/A' } } else { 'N/A' }
        DistinguishedName = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
        DNSHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }
        OperatingSystem = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
        WhenChanged = if ($p['whenchanged'] -and $p['whenchanged'].Count -gt 0) { $p['whenchanged'][0] } else { 'N/A' }
      }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) { $output | Format-Table -AutoSize }
    else { Write-Host 'No findings' -ForegroundColor Gray }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}

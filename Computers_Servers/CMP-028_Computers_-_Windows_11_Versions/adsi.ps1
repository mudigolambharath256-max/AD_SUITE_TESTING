# Check: Computers - Windows 11 Versions
# Category: Computers & Servers
# Severity: info
# ID: CMP-028
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)

# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
$searcher = [ADSISearcher]'(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(operatingSystem=*Windows 11*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'operatingSystem', 'operatingSystemVersion', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

$results = $searcher.FindAll()
Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan

$output = $results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Computers - Windows 11 Versions'
    UserAccountControl = if ($p['useraccountcontrol'] -and $p['useraccountcontrol'].Count -gt 0) { $p['useraccountcontrol'][0] } else { 'N/A' }
    DistinguishedName = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
  }
}

$results.Dispose()
$searcher.Dispose()

if ($output) { $output | Format-Table -AutoSize }
else { Write-Host 'No findings' -ForegroundColor Gray }

} catch {
    Write-Error "AD query failed: $_"
    exit 1
}

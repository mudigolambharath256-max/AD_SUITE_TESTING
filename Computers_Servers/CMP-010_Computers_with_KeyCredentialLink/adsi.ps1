# Check: Computers with KeyCredentialLink
# Category: Computers & Servers
# Severity: medium
# ID: CMP-010
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)

# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
$searcher = [ADSISearcher]'(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(msDS-KeyCredentialLink=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'msDS-KeyCredentialLink', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

$results = $searcher.FindAll()
Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan

$output = $results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Computers with KeyCredentialLink'
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

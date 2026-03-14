# Check: KRBTGT Account Password Age
# Category: Domain Controllers
# Severity: high
# ID: DC-005
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
function Convert-FileTime([object]$val) {
    if ($null -eq $val) { return '(not set)' }
    try {
        $ft = [long]$val
        if ($ft -le 0 -or $ft -eq [long]::MaxValue) { return '(never)' }
        return [DateTime]::FromFileTime($ft).ToString('yyyy-MM-dd HH:mm:ss')
    } catch { return '(invalid)' }
}

    $searcher = [ADSISearcher]'(&(objectCategory=person)(objectClass=user)(samAccountName=krbtgt))'
    $searcher.PageSize = 1000
    $searcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'samAccountName', 'pwdLastSet') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan

    $output = $results | ForEach-Object {
      $p = $_.Properties
      [PSCustomObject]@{
        Label = 'KRBTGT Account Password Age'
        Name = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0]
        SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0]
    SamAccountName = if ($p['samaccountname'] -and $p['samaccountname'].Count -gt 0) { $p['samaccountname'][0] } else { 'N/A' } } else { 'N/A' } } else { 'N/A' }
        DistinguishedName = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
        SamAccountName = if ($p['samAccountName'] -and $p['samAccountName'].Count -gt 0) { $p['samAccountName'][0] } else { 'N/A' }
        PasswordLastSet = if ($p['pwdLastset'] -and $p['pwdLastset'].Count -gt 0) { $p['pwdLastset'][0] } else { 'N/A' }
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

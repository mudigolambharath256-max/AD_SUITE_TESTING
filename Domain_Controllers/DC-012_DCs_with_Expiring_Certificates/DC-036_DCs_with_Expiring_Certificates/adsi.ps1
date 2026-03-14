# Check: DCs with Expiring Certificates
# Category: Domain Controllers
# Severity: high
# ID: DC-036
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
(@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'userCertificate', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

$expirationThreshold = (Get-Date).AddDays(90)

$results = $searcher.FindAll()
Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan

$output = $results | ForEach-Object {
  $p = $_.Properties

  if ($p['usercertificate'].Count -gt 0) {
    foreach ($certBytes in $p['usercertificate']) {
      try {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 @(,$certBytes)

        if ($cert.NotAfter -lt $expirationThreshold) {
          $daysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days

          [PSCustomObject]@{
            Label = 'DCs with Expiring Certificates'
            Name = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0]
        UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
    UserAccountControl = if ($p['useraccountcontrol'] -and $p['useraccountcontrol'].Count -gt 0) { $p['useraccountcontrol'][0] } else { 'N/A' } } else { 'N/A' } } else { 'N/A' }
            DistinguishedName = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
            DNSHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }
            OperatingSystem = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
            CertSubject = $cert.Subject
            CertIssuer = $cert.Issuer
            CertNotAfter = $cert.NotAfter
            DaysUntilExpiry = $daysUntilExpiry
            Status = if ($daysUntilExpiry -lt 0) { "Expired" } elseif ($daysUntilExpiry -lt 30) { "Critical" } else { "Warning" }
          }
        }
      } catch {
        Write-Warning "Unable to parse certificate: $_"
      }
    }
  }
}

$results.Dispose()
$searcher.Dispose()

if ($output) { $output | Format-Table -AutoSize }
else { Write-Host 'No findings' -ForegroundColor Gray }


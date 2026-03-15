# Check: DCs with Expiring Certificates
# Category: Domain Controllers
# Severity: high
# ID: DC-012
# Requirements: None
# ============================================

$root     = [ADSI]'LDAP://RootDSE'
$domainNC = $root.defaultNamingContext.ToString()
$searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.SearchRoot = [ADSI]"LDAP://$domainNC"
$searcher.Filter     = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(userCertificate=*))'
$searcher.PageSize   = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'dNSHostName', 'userCertificate') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })
$results = $searcher.FindAll()
$results | ForEach-Object {
    $p = $_.Properties
    $dcName = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
    if ($p['usercertificate'] -and $p['usercertificate'].Count -gt 0) {
        foreach ($certBytes in $p['usercertificate']) {
            try {
                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certBytes)
                $daysUntilExpiration = ($cert.NotAfter - (Get-Date)).Days
                if ($daysUntilExpiration -le 60) {
                    [PSCustomObject]@{
                        Name = $dcName
                        DistinguishedName = $p['distinguishedname'][0]
                        DNSHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }
                        CertificateSubject = $cert.Subject
                        NotAfter = $cert.NotAfter
                        DaysUntilExpiration = $daysUntilExpiration
                        Status = if ($daysUntilExpiration -lt 0) { "EXPIRED" } elseif ($daysUntilExpiration -le 30) { "CRITICAL" } else { "WARNING" }
                    }
                }
                $cert.Dispose()
            } catch {
                Write-Warning "Certificate parse error for ${dcName}: $_"
            }
        }
    }
}

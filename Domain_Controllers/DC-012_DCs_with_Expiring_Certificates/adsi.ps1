# Check: DCs with Expiring Certificates
# Category: Domain Controllers
# Severity: high
# ID: DC-012
# Requirements: None
# ============================================
# LDAP Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(userCertificate=*))

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
    $root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $searcher.Filter     = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(userCertificate=*))'
    $searcher.PageSize   = 1000
    $searcher.PropertiesToLoad.Clear()
    (@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'userCertificate', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) Domain Controllers with certificates" -ForegroundColor Cyan

    $output = @()

    foreach ($result in $results) {
        $p = $result.Properties
        $dcName = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        # Process certificates
        if ($p['usercertificate'] -and $p['usercertificate'].Count -gt 0) {
            foreach ($certBytes in $p['usercertificate']) {
                try {
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certBytes)

                    # Calculate days until expiration
                    $daysUntilExpiration = ($cert.NotAfter - (Get-Date)).Days

                    # Flag certificates expiring within 60 days or already expired
                    if ($daysUntilExpiration -le 60) {
                        $status = if ($daysUntilExpiration -lt 0) { "EXPIRED" } elseif ($daysUntilExpiration -le 30) { "CRITICAL" } else { "WARNING" }

                        $output += [PSCustomObject]@{
                            Label               = 'DC with Expiring Certificate'
                            Name                = $dcName
                            DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                            DNSHostName         = $dnsHostName
                            OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                            CertificateSubject  = $cert.Subject
                            CertificateIssuer   = $cert.Issuer
                            NotBefore           = $cert.NotBefore
                            NotAfter            = $cert.NotAfter
                            DaysUntilExpiration = $daysUntilExpiration
                            Status              = $status
                            Thumbprint          = $cert.Thumbprint
                            SerialNumber        = $cert.SerialNumber
                            Severity            = if ($daysUntilExpiration -lt 0) { "CRITICAL" } elseif ($daysUntilExpiration -le 30) { "HIGH" } else { "MEDIUM" }
                        }
                    }

                    $cert.Dispose()
                } catch {
                    Write-Warning "Unable to parse certificate for ${dcName}: $_"
                    $output += [PSCustomObject]@{
                        Label               = 'DC with Certificate Parse Error'
                        Name                = $dcName
                        DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                        DNSHostName         = $dnsHostName
                        OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                        CertificateSubject  = "Parse Error"
                        CertificateIssuer   = "Parse Error"
                        NotBefore           = "Parse Error"
                        NotAfter            = "Parse Error"
                        DaysUntilExpiration = "Parse Error"
                        Status              = "ERROR"
                        Thumbprint          = "Parse Error"
                        SerialNumber        = "Parse Error"
                        Severity            = "UNKNOWN"
                    }
                }
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize


# ============================================================================
# BLOODHOUND EXPORT BLOCK
# ============================================================================
# Automatically export results to BloodHound-compatible JSON format
# ============================================================================

try {
    # Initialize session
    if (-not $env:ADSUITE_SESSION_ID) {
        $env:ADSUITE_SESSION_ID = Get-Date -Format 'yyyyMMdd_HHmmss'
        Write-Host "[BloodHound] New session: $env:ADSUITE_SESSION_ID" -ForegroundColor Cyan
    }
    
    $bhDir = "C:\ADSuite_BloodHound\SESSION_$env:ADSUITE_SESSION_ID"
    if (-not (Test-Path $bhDir)) {
        New-Item -ItemType Directory -Path $bhDir -Force | Out-Null
    }
    
    # Convert results to BloodHound format
    if ($results -and $results.Count -gt 0) {
        $bhNodes = @()
        
        foreach ($item in $results) {
            # Extract SID as ObjectIdentifier
            $objectId = if ($item.objectSid) {
                try {
                    (New-Object System.Security.Principal.SecurityIdentifier($item.objectSid, 0)).Value
                } catch {
                    $item.DistinguishedName
                }
            } else {
                $item.DistinguishedName
            }
            
            # Determine object type
            $objectType = if ($item.objectClass -contains 'user') { 'User' }
                         elseif ($item.objectClass -contains 'computer') { 'Computer' }
                         elseif ($item.objectClass -contains 'group') { 'Group' }
                         else { 'Base' }
            
            # Extract domain from DN
            $domain = if ($item.DistinguishedName -match 'DC=([^,]+)') {
                ($matches[1..($matches.Count-1)] -join '.').ToUpper()
            } else { 'UNKNOWN' }
            
            $bhNodes += @{
                ObjectIdentifier = $objectId
                ObjectType = $objectType
                Properties = @{
                    name = $item.Name
                    distinguishedname = $item.DistinguishedName
                    samaccountname = $item.samAccountName
                    domain = $domain
                    checkid = 'DC-012'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-012_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Expiring Certificates
# Category: Domain Controllers
# Severity: high
# ID: DC-012
# Requirements: None
# ============================================
# LDAP Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(userCertificate=*))

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
    $root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $searcher.Filter     = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(userCertificate=*))'
    $searcher.PageSize   = 1000
    $searcher.PropertiesToLoad.Clear()
    (@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'userCertificate', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) Domain Controllers with certificates" -ForegroundColor Cyan

    $output = @()

    foreach ($result in $results) {
        $p = $result.Properties
        $dcName = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        # Process certificates
        if ($p['usercertificate'] -and $p['usercertificate'].Count -gt 0) {
            foreach ($certBytes in $p['usercertificate']) {
                try {
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certBytes)

                    # Calculate days until expiration
                    $daysUntilExpiration = ($cert.NotAfter - (Get-Date)).Days

                    # Flag certificates expiring within 60 days or already expired
                    if ($daysUntilExpiration -le 60) {
                        $status = if ($daysUntilExpiration -lt 0) { "EXPIRED" } elseif ($daysUntilExpiration -le 30) { "CRITICAL" } else { "WARNING" }

                        $output += [PSCustomObject]@{
                            Label               = 'DC with Expiring Certificate'
                            Name                = $dcName
                            DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                            DNSHostName         = $dnsHostName
                            OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                            CertificateSubject  = $cert.Subject
                            CertificateIssuer   = $cert.Issuer
                            NotBefore           = $cert.NotBefore
                            NotAfter            = $cert.NotAfter
                            DaysUntilExpiration = $daysUntilExpiration
                            Status              = $status
                            Thumbprint          = $cert.Thumbprint
                            SerialNumber        = $cert.SerialNumber
                            Severity            = if ($daysUntilExpiration -lt 0) { "CRITICAL" } elseif ($daysUntilExpiration -le 30) { "HIGH" } else { "MEDIUM" }
                        }
                    }

                    $cert.Dispose()
                } catch {
                    Write-Warning "Unable to parse certificate for ${dcName}: $_"
                    $output += [PSCustomObject]@{
                        Label               = 'DC with Certificate Parse Error'
                        Name                = $dcName
                        DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                        DNSHostName         = $dnsHostName
                        OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                        CertificateSubject  = "Parse Error"
                        CertificateIssuer   = "Parse Error"
                        NotBefore           = "Parse Error"
                        NotAfter            = "Parse Error"
                        DaysUntilExpiration = "Parse Error"
                        Status              = "ERROR"
                        Thumbprint          = "Parse Error"
                        SerialNumber        = "Parse Error"
                        Severity            = "UNKNOWN"
                    }
                }
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        $expiredCount = ($output | Where-Object { $_.Status -eq "EXPIRED" }).Count
        $criticalCount = ($output | Where-Object { $_.Status -eq "CRITICAL" }).Count
        $warningCount = ($output | Where-Object { $_.Status -eq "WARNING" }).Count

        Write-Host "`nSummary: Found $($output.Count) certificates requiring attention" -ForegroundColor Yellow
        Write-Host "  - Expired: $expiredCount" -ForegroundColor Red
        Write-Host "  - Critical (≤30 days): $criticalCount" -ForegroundColor Red
        Write-Host "  - Warning (≤60 days): $warningCount" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controller certificates are valid for more than 60 days' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory certificate query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        $expiredCount = ($output | Where-Object { $_.Status -eq "EXPIRED" }).Count
        $criticalCount = ($output | Where-Object { $_.Status -eq "CRITICAL" }).Count
        $warningCount = ($output | Where-Object { $_.Status -eq "WARNING" }).Count

        Write-Host "`nSummary: Found $($output.Count) certificates requiring attention" -ForegroundColor Yellow
        Write-Host "  - Expired: $expiredCount" -ForegroundColor Red
        Write-Host "  - Critical (≤30 days): $criticalCount" -ForegroundColor Red
        Write-Host "  - Warning (≤60 days): $warningCount" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controller certificates are valid for more than 60 days' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory certificate query failed: $_"
    exit 1
}
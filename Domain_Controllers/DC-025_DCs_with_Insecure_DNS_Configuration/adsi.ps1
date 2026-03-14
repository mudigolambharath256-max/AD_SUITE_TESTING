# Check: DCs with Insecure DNS Configuration
# Category: Domain Controllers
# Severity: high
# ID: DC-025
# Requirements: None
# ============================================
# LDAP Filter: (objectClass=dnsZone)

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $root = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
    $configNC = $root.configurationNamingContext.ToString()

    # First get all DCs for context
    $dcSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $dcSearcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $dcSearcher.Filter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $dcSearcher.PageSize = 1000
    $dcSearcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'dNSHostName', 'objectSid', 'samAccountName') | ForEach-Object { [void]$dcSearcher.PropertiesToLoad.Add($_) }

    $dcResults = $dcSearcher.FindAll()
    Write-Host "Found $($dcResults.Count) Domain Controllers" -ForegroundColor Cyan

    $output = @()

    # Check DNS zones in different partitions
    $dnsPartitions = @{
        "DomainDnsZones" = "DC=DomainDnsZones,$domainNC"
        "ForestDnsZones" = "DC=ForestDnsZones,$domainNC"
        "System" = "CN=MicrosoftDNS,CN=System,$domainNC"
    }

    foreach ($partitionName in $dnsPartitions.Keys) {
        $partitionDN = $dnsPartitions[$partitionName]

        try {
            $dnsSearcher = New-Object System.DirectoryServices.DirectorySearcher
            $dnsSearcher.SearchRoot = [ADSI]"LDAP://$partitionDN"
            $dnsSearcher.Filter = '(objectClass=dnsZone)'
            $dnsSearcher.PageSize = 1000
            $dnsSearcher.PropertiesToLoad.Clear()
            @('name', 'distinguishedName', 'dNSProperty', 'dnsRecord', 'objectSid', 'samAccountName') | ForEach-Object { [void]$dnsSearcher.PropertiesToLoad.Add($_) }

            $dnsResults = $dnsSearcher.FindAll()

            foreach ($zone in $dnsResults) {
                $p = $zone.Properties
                $zoneName = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }

                # Skip system zones
                if ($zoneName -match '^(_msdcs|_sites|_tcp|_udp|\.\.|@)') {
                    continue
                }

                $issues = @()
                $severity = "MEDIUM"

                # Check DNS properties for insecure settings
                if ($p['dnsproperty'] -and $p['dnsproperty'].Count -gt 0) {
                    foreach ($property in $p['dnsproperty']) {
                        try {
                            # DNS properties are binary - basic checks for common issues
                            $propertyHex = [System.BitConverter]::ToString($property).Replace('-', '')

                            # Check for common insecure patterns (simplified)
                            if ($propertyHex -match '01000000') {
                                $issues += "Zone may allow non-secure dynamic updates"
                                $severity = "HIGH"
                            }
                        } catch {
                            # Property parsing failed, continue
                        }
                    }
                }

                # Check for wildcard records
                if ($p['dnsrecord'] -and $p['dnsrecord'].Count -gt 0) {
                    if ($zoneName -eq "*") {
                        $issues += "Wildcard DNS zone detected"
                        $severity = "HIGH"
                    }
                }

                # Check zone name for potential issues
                if ($zoneName -match '\*') {
                    $issues += "Zone name contains wildcard characters"
                    $severity = "HIGH"
                }

                # Flag zones in legacy System partition (should be in application partitions)
                if ($partitionName -eq "System") {
                    $issues += "DNS zone in legacy System partition (should be in DomainDnsZones)"
                    $severity = "MEDIUM"
                }

                if ($issues.Count -gt 0) {
                    $output += [PSCustomObject]@{
                        Label               = 'DC with Insecure DNS Configuration'
                        ZoneName            = $zoneName
                        Partition           = $partitionName
                        DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                        Issues              = ($issues -join '; ')
                        IssueCount          = $issues.Count
                        Severity            = $severity
                        Risk                = "DNS poisoning, zone transfer attacks, unauthorized updates"
                        Recommendation      = "Review DNS zone security settings and dynamic update policies"
                    }
                }
            }

            $dnsResults.Dispose()
            $dnsSearcher.Dispose()
        } catch {
            Write-Warning "Unable to query DNS partition ${partitionName}: $_"
        }
    }

    $dcResults.Dispose()
    $dcSearcher.Dispose()

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
                    checkid = 'DC-025'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-025_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Insecure DNS Configuration
# Category: Domain Controllers
# Severity: high
# ID: DC-025
# Requirements: None
# ============================================
# LDAP Filter: (objectClass=dnsZone)

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $root = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
    $configNC = $root.configurationNamingContext.ToString()

    # First get all DCs for context
    $dcSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $dcSearcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $dcSearcher.Filter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $dcSearcher.PageSize = 1000
    $dcSearcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'dNSHostName', 'objectSid', 'samAccountName') | ForEach-Object { [void]$dcSearcher.PropertiesToLoad.Add($_) }

    $dcResults = $dcSearcher.FindAll()
    Write-Host "Found $($dcResults.Count) Domain Controllers" -ForegroundColor Cyan

    $output = @()

    # Check DNS zones in different partitions
    $dnsPartitions = @{
        "DomainDnsZones" = "DC=DomainDnsZones,$domainNC"
        "ForestDnsZones" = "DC=ForestDnsZones,$domainNC"
        "System" = "CN=MicrosoftDNS,CN=System,$domainNC"
    }

    foreach ($partitionName in $dnsPartitions.Keys) {
        $partitionDN = $dnsPartitions[$partitionName]

        try {
            $dnsSearcher = New-Object System.DirectoryServices.DirectorySearcher
            $dnsSearcher.SearchRoot = [ADSI]"LDAP://$partitionDN"
            $dnsSearcher.Filter = '(objectClass=dnsZone)'
            $dnsSearcher.PageSize = 1000
            $dnsSearcher.PropertiesToLoad.Clear()
            @('name', 'distinguishedName', 'dNSProperty', 'dnsRecord', 'objectSid', 'samAccountName') | ForEach-Object { [void]$dnsSearcher.PropertiesToLoad.Add($_) }

            $dnsResults = $dnsSearcher.FindAll()

            foreach ($zone in $dnsResults) {
                $p = $zone.Properties
                $zoneName = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }

                # Skip system zones
                if ($zoneName -match '^(_msdcs|_sites|_tcp|_udp|\.\.|@)') {
                    continue
                }

                $issues = @()
                $severity = "MEDIUM"

                # Check DNS properties for insecure settings
                if ($p['dnsproperty'] -and $p['dnsproperty'].Count -gt 0) {
                    foreach ($property in $p['dnsproperty']) {
                        try {
                            # DNS properties are binary - basic checks for common issues
                            $propertyHex = [System.BitConverter]::ToString($property).Replace('-', '')

                            # Check for common insecure patterns (simplified)
                            if ($propertyHex -match '01000000') {
                                $issues += "Zone may allow non-secure dynamic updates"
                                $severity = "HIGH"
                            }
                        } catch {
                            # Property parsing failed, continue
                        }
                    }
                }

                # Check for wildcard records
                if ($p['dnsrecord'] -and $p['dnsrecord'].Count -gt 0) {
                    if ($zoneName -eq "*") {
                        $issues += "Wildcard DNS zone detected"
                        $severity = "HIGH"
                    }
                }

                # Check zone name for potential issues
                if ($zoneName -match '\*') {
                    $issues += "Zone name contains wildcard characters"
                    $severity = "HIGH"
                }

                # Flag zones in legacy System partition (should be in application partitions)
                if ($partitionName -eq "System") {
                    $issues += "DNS zone in legacy System partition (should be in DomainDnsZones)"
                    $severity = "MEDIUM"
                }

                if ($issues.Count -gt 0) {
                    $output += [PSCustomObject]@{
                        Label               = 'DC with Insecure DNS Configuration'
                        ZoneName            = $zoneName
                        Partition           = $partitionName
                        DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                        Issues              = ($issues -join '; ')
                        IssueCount          = $issues.Count
                        Severity            = $severity
                        Risk                = "DNS poisoning, zone transfer attacks, unauthorized updates"
                        Recommendation      = "Review DNS zone security settings and dynamic update policies"
                    }
                }
            }

            $dnsResults.Dispose()
            $dnsSearcher.Dispose()
        } catch {
            Write-Warning "Unable to query DNS partition ${partitionName}: $_"
        }
    }

    $dcResults.Dispose()
    $dcSearcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) DNS zones with security issues" -ForegroundColor Yellow
        Write-Host "Note: DNS property analysis is simplified. Use dnscmd for detailed zone security review." -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - DNS zones appear to have secure configurations' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory DNS query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) DNS zones with security issues" -ForegroundColor Yellow
        Write-Host "Note: DNS property analysis is simplified. Use dnscmd for detailed zone security review." -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - DNS zones appear to have secure configurations' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory DNS query failed: $_"
    exit 1
}
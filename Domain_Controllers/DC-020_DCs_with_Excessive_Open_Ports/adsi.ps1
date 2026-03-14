# Check: DCs with Excessive Open Ports
# Category: Domain Controllers
# Severity: medium
# ID: DC-020
# Requirements: None
# ============================================
# Use Test-NetConnection to check standard DC ports

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + Network
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $searcher.Filter     = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $searcher.PageSize   = 1000
    $searcher.PropertiesToLoad.Clear()
    (@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'userAccountControl', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) Domain Controllers" -ForegroundColor Cyan

    # Define standard DC ports (expected)
    $standardDCPorts = @{
        53   = "DNS"
        88   = "Kerberos"
        135  = "RPC Endpoint Mapper"
        139  = "NetBIOS Session"
        389  = "LDAP"
        445  = "SMB"
        464  = "Kerberos Password Change"
        636  = "LDAPS"
        3268 = "Global Catalog"
        3269 = "Global Catalog SSL"
    }

    # Define suspicious/non-standard ports
    $suspiciousPorts = @{
        21   = "FTP"
        23   = "Telnet"
        80   = "HTTP"
        443  = "HTTPS"
        3389 = "RDP"
        8080 = "HTTP Alternate"
        1433 = "SQL Server"
        3306 = "MySQL"
        5432 = "PostgreSQL"
        22   = "SSH"
    }

    $output = @()

    foreach ($result in $results) {
        $p = $result.Properties
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        # Skip if no DNS hostname
        if ($dnsHostName -eq 'N/A') {
            Write-Warning "Skipping DC with no DNS hostname: $($p['name'][0])"
            continue
        }

        try {
            Write-Host "Scanning ports on $dnsHostName..." -ForegroundColor Gray

            $openSuspiciousPorts = @()
            $missingStandardPorts = @()

            # Check for suspicious ports
            foreach ($port in $suspiciousPorts.Keys) {
                try {
                    $connection = Test-NetConnection -ComputerName $dnsHostName -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                    if ($connection) {
                        $openSuspiciousPorts += "$port ($($suspiciousPorts[$port]))"
                    }
                } catch {
                    # Port test failed, assume closed
                }
            }

            # Check for missing standard ports (optional - may indicate service issues)
            foreach ($port in $standardDCPorts.Keys) {
                try {
                    $connection = Test-NetConnection -ComputerName $dnsHostName -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                    if (-not $connection) {
                        $missingStandardPorts += "$port ($($standardDCPorts[$port]))"
                    }
                } catch {
                    $missingStandardPorts += "$port ($($standardDCPorts[$port])) - Test Failed"
                }
            }

            # Flag if suspicious ports are open
            if ($openSuspiciousPorts.Count -gt 0) {
                $severity = "MEDIUM"
                if ($openSuspiciousPorts -match "3389|21|23") {
                    $severity = "HIGH"  # RDP, FTP, Telnet are high risk
                }

                $output += [PSCustomObject]@{
                    Label                   = 'DC with Excessive Open Ports'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    SuspiciousOpenPorts     = ($openSuspiciousPorts -join ', ')
                    MissingStandardPorts    = if ($missingStandardPorts.Count -gt 0) { ($missingStandardPorts -join ', ') } else { "None" }
                    PortCount               = $openSuspiciousPorts.Count
                    Severity                = $severity
                    Risk                    = "Unnecessary attack surface, potential unauthorized services"
                    Recommendation          = "Review and disable unnecessary services"
                }
            }
        } catch {
            # Handle network access failures
            Write-Warning "Unable to scan ports on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC Port Scan Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                SuspiciousOpenPorts     = "Network Scan Failed"
                MissingStandardPorts    = "Network Scan Failed"
                PortCount               = "Unknown"
                Severity                = "UNKNOWN"
                Risk                    = "Unable to verify port configuration"
                Recommendation          = "Manual port scan required"
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
                    checkid = 'DC-020'
                    severity = 'medium'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-020_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Excessive Open Ports
# Category: Domain Controllers
# Severity: medium
# ID: DC-020
# Requirements: None
# ============================================
# Use Test-NetConnection to check standard DC ports

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + Network
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $searcher.Filter     = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $searcher.PageSize   = 1000
    $searcher.PropertiesToLoad.Clear()
    (@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'userAccountControl', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) Domain Controllers" -ForegroundColor Cyan

    # Define standard DC ports (expected)
    $standardDCPorts = @{
        53   = "DNS"
        88   = "Kerberos"
        135  = "RPC Endpoint Mapper"
        139  = "NetBIOS Session"
        389  = "LDAP"
        445  = "SMB"
        464  = "Kerberos Password Change"
        636  = "LDAPS"
        3268 = "Global Catalog"
        3269 = "Global Catalog SSL"
    }

    # Define suspicious/non-standard ports
    $suspiciousPorts = @{
        21   = "FTP"
        23   = "Telnet"
        80   = "HTTP"
        443  = "HTTPS"
        3389 = "RDP"
        8080 = "HTTP Alternate"
        1433 = "SQL Server"
        3306 = "MySQL"
        5432 = "PostgreSQL"
        22   = "SSH"
    }

    $output = @()

    foreach ($result in $results) {
        $p = $result.Properties
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        # Skip if no DNS hostname
        if ($dnsHostName -eq 'N/A') {
            Write-Warning "Skipping DC with no DNS hostname: $($p['name'][0])"
            continue
        }

        try {
            Write-Host "Scanning ports on $dnsHostName..." -ForegroundColor Gray

            $openSuspiciousPorts = @()
            $missingStandardPorts = @()

            # Check for suspicious ports
            foreach ($port in $suspiciousPorts.Keys) {
                try {
                    $connection = Test-NetConnection -ComputerName $dnsHostName -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                    if ($connection) {
                        $openSuspiciousPorts += "$port ($($suspiciousPorts[$port]))"
                    }
                } catch {
                    # Port test failed, assume closed
                }
            }

            # Check for missing standard ports (optional - may indicate service issues)
            foreach ($port in $standardDCPorts.Keys) {
                try {
                    $connection = Test-NetConnection -ComputerName $dnsHostName -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                    if (-not $connection) {
                        $missingStandardPorts += "$port ($($standardDCPorts[$port]))"
                    }
                } catch {
                    $missingStandardPorts += "$port ($($standardDCPorts[$port])) - Test Failed"
                }
            }

            # Flag if suspicious ports are open
            if ($openSuspiciousPorts.Count -gt 0) {
                $severity = "MEDIUM"
                if ($openSuspiciousPorts -match "3389|21|23") {
                    $severity = "HIGH"  # RDP, FTP, Telnet are high risk
                }

                $output += [PSCustomObject]@{
                    Label                   = 'DC with Excessive Open Ports'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    SuspiciousOpenPorts     = ($openSuspiciousPorts -join ', ')
                    MissingStandardPorts    = if ($missingStandardPorts.Count -gt 0) { ($missingStandardPorts -join ', ') } else { "None" }
                    PortCount               = $openSuspiciousPorts.Count
                    Severity                = $severity
                    Risk                    = "Unnecessary attack surface, potential unauthorized services"
                    Recommendation          = "Review and disable unnecessary services"
                }
            }
        } catch {
            # Handle network access failures
            Write-Warning "Unable to scan ports on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC Port Scan Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                SuspiciousOpenPorts     = "Network Scan Failed"
                MissingStandardPorts    = "Network Scan Failed"
                PortCount               = "Unknown"
                Severity                = "UNKNOWN"
                Risk                    = "Unable to verify port configuration"
                Recommendation          = "Manual port scan required"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        $highRisk = ($output | Where-Object { $_.Severity -eq "HIGH" }).Count
        $mediumRisk = ($output | Where-Object { $_.Severity -eq "MEDIUM" }).Count

        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with port issues" -ForegroundColor Yellow
        Write-Host "  - High Risk (RDP/FTP/Telnet): $highRisk" -ForegroundColor Red
        Write-Host "  - Medium Risk (Other services): $mediumRisk" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have appropriate port configurations' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        $highRisk = ($output | Where-Object { $_.Severity -eq "HIGH" }).Count
        $mediumRisk = ($output | Where-Object { $_.Severity -eq "MEDIUM" }).Count

        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with port issues" -ForegroundColor Yellow
        Write-Host "  - High Risk (RDP/FTP/Telnet): $highRisk" -ForegroundColor Red
        Write-Host "  - Medium Risk (Other services): $mediumRisk" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have appropriate port configurations' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
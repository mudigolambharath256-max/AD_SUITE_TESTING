# Check: DCs with Print Spooler Running
# Category: Domain Controllers
# Severity: critical
# ID: DC-015
# Requirements: None
# ============================================
# WMI: Win32_Service WHERE Name='Spooler'

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + WMI
# FalsePositiveRisk   : Low
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

    $output = $results | ForEach-Object {
        $p = $_.Properties
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        # Skip if no DNS hostname
        if ($dnsHostName -eq 'N/A') {
            Write-Warning "Skipping DC with no DNS hostname: $($p['name'][0])"
            return
        }

        try {
            # Check Print Spooler service via WMI
            $spoolerService = Get-WmiObject -Class Win32_Service -ComputerName $dnsHostName -Filter "Name='Spooler'" -ErrorAction Stop

            # Flag if Print Spooler is running or set to auto-start
            if ($spoolerService -and ($spoolerService.State -eq 'Running' -or $spoolerService.StartMode -eq 'Auto')) {
                [PSCustomObject]@{
                    Label             = 'DCs with Print Spooler Running'
                    Name              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName       = $dnsHostName
                    OperatingSystem   = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    ServiceState      = if ($spoolerService) { $spoolerService.State } else { 'Unknown' }
                    StartMode         = if ($spoolerService) { $spoolerService.StartMode } else { 'Unknown' }
                    Severity          = "CRITICAL"
                    MITRE             = "T1187"
                    CVE               = "CVE-2021-1678, CVE-2021-34527"
                    Risk              = "SpoolSample/PrinterBug attacks, PrintNightmare vulnerability"
                }
            }
        } catch {
            # Handle WMI access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check Print Spooler service on ${dnsHostName}: $_"
            [PSCustomObject]@{
                Label             = 'DCs with Print Spooler Running'
                Name              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName       = $dnsHostName
                OperatingSystem   = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                ServiceState      = "UNKNOWN - WMI Unavailable"
                StartMode         = "Access Denied"
                Severity          = "UNKNOWN"
                MITRE             = "T1187"
                CVE               = "CVE-2021-1678, CVE-2021-34527"
                Risk              = "Unable to verify Print Spooler status"
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
                    checkid = 'DC-015'
                    severity = 'critical'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-015_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Print Spooler Running
# Category: Domain Controllers
# Severity: critical
# ID: DC-015
# Requirements: None
# ============================================
# WMI: Win32_Service WHERE Name='Spooler'

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + WMI
# FalsePositiveRisk   : Low
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

    $output = $results | ForEach-Object {
        $p = $_.Properties
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        # Skip if no DNS hostname
        if ($dnsHostName -eq 'N/A') {
            Write-Warning "Skipping DC with no DNS hostname: $($p['name'][0])"
            return
        }

        try {
            # Check Print Spooler service via WMI
            $spoolerService = Get-WmiObject -Class Win32_Service -ComputerName $dnsHostName -Filter "Name='Spooler'" -ErrorAction Stop

            # Flag if Print Spooler is running or set to auto-start
            if ($spoolerService -and ($spoolerService.State -eq 'Running' -or $spoolerService.StartMode -eq 'Auto')) {
                [PSCustomObject]@{
                    Label             = 'DCs with Print Spooler Running'
                    Name              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName       = $dnsHostName
                    OperatingSystem   = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    ServiceState      = if ($spoolerService) { $spoolerService.State } else { 'Unknown' }
                    StartMode         = if ($spoolerService) { $spoolerService.StartMode } else { 'Unknown' }
                    Severity          = "CRITICAL"
                    MITRE             = "T1187"
                    CVE               = "CVE-2021-1678, CVE-2021-34527"
                    Risk              = "SpoolSample/PrinterBug attacks, PrintNightmare vulnerability"
                }
            }
        } catch {
            # Handle WMI access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check Print Spooler service on ${dnsHostName}: $_"
            [PSCustomObject]@{
                Label             = 'DCs with Print Spooler Running'
                Name              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName       = $dnsHostName
                OperatingSystem   = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                ServiceState      = "UNKNOWN - WMI Unavailable"
                StartMode         = "Access Denied"
                Severity          = "UNKNOWN"
                MITRE             = "T1187"
                CVE               = "CVE-2021-1678, CVE-2021-34527"
                Risk              = "Unable to verify Print Spooler status"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with Print Spooler issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have Print Spooler properly disabled' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with Print Spooler issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have Print Spooler properly disabled' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
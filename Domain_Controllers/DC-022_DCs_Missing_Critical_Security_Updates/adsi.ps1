# Check: DCs Missing Critical Security Updates
# Category: Domain Controllers
# Severity: critical
# ID: DC-022
# Requirements: None
# ============================================
# WMI: SELECT HotFixID,InstalledOn FROM Win32_QuickFixEngineering

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP + WMI
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

    # Define critical security updates to check for
    $criticalUpdates = @{
        "KB5008380" = "PrintNightmare (CVE-2021-34527)"
        "KB5008602" = "PrintNightmare Additional Fix"
        "KB4571694" = "Zerologon (CVE-2020-1472)"
        "KB5005413" = "PetitPotam (CVE-2021-36942)"
        "KB5014754" = "PAC Security (CVE-2022-26925)"
        "KB5016138" = "Kerberos Authentication Bypass"
        "KB5020805" = "ESU Authentication Bypass"
        "KB5021234" = "Windows Kerberos Elevation of Privilege"
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
            Write-Host "Checking updates on $dnsHostName..." -ForegroundColor Gray

            # Get installed hotfixes via WMI
            $installedUpdates = Get-WmiObject -Class Win32_QuickFixEngineering -ComputerName $dnsHostName -ErrorAction Stop
            $installedKBs = $installedUpdates | ForEach-Object { $_.HotFixID }

            # Check for missing critical updates
            $missingUpdates = @()
            $installedCriticalUpdates = @()

            foreach ($kb in $criticalUpdates.Keys) {
                if ($installedKBs -contains $kb) {
                    $installedCriticalUpdates += "$kb ($($criticalUpdates[$kb]))"
                } else {
                    $missingUpdates += "$kb ($($criticalUpdates[$kb]))"
                }
            }

            # Get OS version to determine applicable updates
            $osVersion = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'Unknown' }

            # Flag if critical updates are missing
            if ($missingUpdates.Count -gt 0) {
                $severity = "CRITICAL"
                if ($missingUpdates -match "KB4571694|KB5008380") {
                    $severity = "CRITICAL"  # Zerologon and PrintNightmare are most critical
                }

                $output += [PSCustomObject]@{
                    Label                       = 'DC Missing Critical Security Updates'
                    Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName                 = $dnsHostName
                    OperatingSystem             = $osVersion
                    MissingCriticalUpdates      = ($missingUpdates -join '; ')
                    InstalledCriticalUpdates    = if ($installedCriticalUpdates.Count -gt 0) { ($installedCriticalUpdates -join '; ') } else { "None" }
                    MissingCount                = $missingUpdates.Count
                    TotalUpdatesInstalled       = $installedUpdates.Count
                    LastUpdateCheck             = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    Severity                    = $severity
                    Risk                        = "Known vulnerabilities exploitable by attackers"
                    Recommendation              = "Install missing security updates immediately"
                }
            }
        } catch {
            # Handle WMI access failures
            Write-Warning "Unable to check updates on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                       = 'DC Update Check Failed'
                Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName                 = $dnsHostName
                OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                MissingCriticalUpdates      = "WMI Access Failed"
                InstalledCriticalUpdates    = "Unable to verify"
                MissingCount                = "Unknown"
                TotalUpdatesInstalled       = "Access Denied"
                LastUpdateCheck             = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                Severity                    = "UNKNOWN"
                Risk                        = "Unable to verify patch status"
                Recommendation              = "Manual update verification required"
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
                    checkid = 'DC-022'
                    severity = 'critical'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-022_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs Missing Critical Security Updates
# Category: Domain Controllers
# Severity: critical
# ID: DC-022
# Requirements: None
# ============================================
# WMI: SELECT HotFixID,InstalledOn FROM Win32_QuickFixEngineering

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP + WMI
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

    # Define critical security updates to check for
    $criticalUpdates = @{
        "KB5008380" = "PrintNightmare (CVE-2021-34527)"
        "KB5008602" = "PrintNightmare Additional Fix"
        "KB4571694" = "Zerologon (CVE-2020-1472)"
        "KB5005413" = "PetitPotam (CVE-2021-36942)"
        "KB5014754" = "PAC Security (CVE-2022-26925)"
        "KB5016138" = "Kerberos Authentication Bypass"
        "KB5020805" = "ESU Authentication Bypass"
        "KB5021234" = "Windows Kerberos Elevation of Privilege"
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
            Write-Host "Checking updates on $dnsHostName..." -ForegroundColor Gray

            # Get installed hotfixes via WMI
            $installedUpdates = Get-WmiObject -Class Win32_QuickFixEngineering -ComputerName $dnsHostName -ErrorAction Stop
            $installedKBs = $installedUpdates | ForEach-Object { $_.HotFixID }

            # Check for missing critical updates
            $missingUpdates = @()
            $installedCriticalUpdates = @()

            foreach ($kb in $criticalUpdates.Keys) {
                if ($installedKBs -contains $kb) {
                    $installedCriticalUpdates += "$kb ($($criticalUpdates[$kb]))"
                } else {
                    $missingUpdates += "$kb ($($criticalUpdates[$kb]))"
                }
            }

            # Get OS version to determine applicable updates
            $osVersion = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'Unknown' }

            # Flag if critical updates are missing
            if ($missingUpdates.Count -gt 0) {
                $severity = "CRITICAL"
                if ($missingUpdates -match "KB4571694|KB5008380") {
                    $severity = "CRITICAL"  # Zerologon and PrintNightmare are most critical
                }

                $output += [PSCustomObject]@{
                    Label                       = 'DC Missing Critical Security Updates'
                    Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName                 = $dnsHostName
                    OperatingSystem             = $osVersion
                    MissingCriticalUpdates      = ($missingUpdates -join '; ')
                    InstalledCriticalUpdates    = if ($installedCriticalUpdates.Count -gt 0) { ($installedCriticalUpdates -join '; ') } else { "None" }
                    MissingCount                = $missingUpdates.Count
                    TotalUpdatesInstalled       = $installedUpdates.Count
                    LastUpdateCheck             = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    Severity                    = $severity
                    Risk                        = "Known vulnerabilities exploitable by attackers"
                    Recommendation              = "Install missing security updates immediately"
                }
            }
        } catch {
            # Handle WMI access failures
            Write-Warning "Unable to check updates on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                       = 'DC Update Check Failed'
                Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName                 = $dnsHostName
                OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                MissingCriticalUpdates      = "WMI Access Failed"
                InstalledCriticalUpdates    = "Unable to verify"
                MissingCount                = "Unknown"
                TotalUpdatesInstalled       = "Access Denied"
                LastUpdateCheck             = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                Severity                    = "UNKNOWN"
                Risk                        = "Unable to verify patch status"
                Recommendation              = "Manual update verification required"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with missing critical updates" -ForegroundColor Red
        Write-Host "Note: WMI may not show all installed updates. Consider using WSUS/SCCM reports for complete verification." -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers appear to have critical security updates installed' -ForegroundColor Green
        Write-Host "Note: This check has limitations. Verify with WSUS/SCCM for complete patch status." -ForegroundColor Yellow
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with missing critical updates" -ForegroundColor Red
        Write-Host "Note: WMI may not show all installed updates. Consider using WSUS/SCCM reports for complete verification." -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers appear to have critical security updates installed' -ForegroundColor Green
        Write-Host "Note: This check has limitations. Verify with WSUS/SCCM for complete patch status." -ForegroundColor Yellow
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
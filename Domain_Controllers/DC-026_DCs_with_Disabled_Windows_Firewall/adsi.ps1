# Check: DCs with Disabled Windows Firewall
# Category: Domain Controllers
# Severity: high
# ID: DC-026
# Requirements: None
# ============================================
# Registry: HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\*Profile\EnableFirewall

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + Registry + WMI
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
            # Check Windows Firewall status via registry
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)

            $firewallProfiles = @{
                "Domain" = "SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile"
                "Standard" = "SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile"
                "Public" = "SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile"
            }

            $profileStatus = @{}
            $disabledProfiles = @()

            foreach ($profileName in $firewallProfiles.Keys) {
                $profilePath = $firewallProfiles[$profileName]
                $profileKey = $reg.OpenSubKey($profilePath)

                if ($profileKey) {
                    $enableFirewall = $profileKey.GetValue("EnableFirewall")
                    $profileStatus[$profileName] = if ($enableFirewall -eq 1) { "Enabled" } else { "Disabled" }

                    if ($enableFirewall -ne 1) {
                        $disabledProfiles += $profileName
                    }

                    $profileKey.Close()
                } else {
                    $profileStatus[$profileName] = "Unknown"
                    $disabledProfiles += "$profileName (Registry Key Missing)"
                }
            }

            $reg.Close()

            # Also try to check via WMI/PowerShell if available
            $wmiFirewallStatus = @{}
            try {
                # Try to get firewall profile status via WMI
                $firewallProfiles = Get-WmiObject -Class Win32_Service -ComputerName $dnsHostName -Filter "Name='MpsSvc'" -ErrorAction SilentlyContinue
                if ($firewallProfiles -and $firewallProfiles.State -ne "Running") {
                    $disabledProfiles += "Windows Firewall Service Not Running"
                }
            } catch {
                # WMI access may fail, continue with registry data
            }

            # Flag if any firewall profiles are disabled
            if ($disabledProfiles.Count -gt 0) {
                $severity = "HIGH"
                if ($disabledProfiles -contains "Domain") {
                    $severity = "CRITICAL"  # Domain profile disabled is most critical for DCs
                }

                $output += [PSCustomObject]@{
                    Label                   = 'DC with Disabled Windows Firewall'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    DomainProfile           = $profileStatus["Domain"]
                    StandardProfile         = $profileStatus["Standard"]
                    PublicProfile           = $profileStatus["Public"]
                    DisabledProfiles        = ($disabledProfiles -join ', ')
                    DisabledCount           = $disabledProfiles.Count
                    Severity                = $severity
                    Risk                    = "Unfiltered network access, increased attack surface"
                    Recommendation          = "Enable Windows Firewall on all profiles"
                }
            }
        } catch {
            # Handle remote access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check Windows Firewall on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC Firewall Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                DomainProfile           = "Access Denied"
                StandardProfile         = "Access Denied"
                PublicProfile           = "Access Denied"
                DisabledProfiles        = "Unable to verify firewall status"
                DisabledCount           = "Unknown"
                Severity                = "UNKNOWN"
                Risk                    = "Unable to verify firewall configuration"
                Recommendation          = "Manual verification required"
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
                    checkid = 'DC-026'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-026_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Disabled Windows Firewall
# Category: Domain Controllers
# Severity: high
# ID: DC-026
# Requirements: None
# ============================================
# Registry: HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\*Profile\EnableFirewall

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + Registry + WMI
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
            # Check Windows Firewall status via registry
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)

            $firewallProfiles = @{
                "Domain" = "SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile"
                "Standard" = "SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile"
                "Public" = "SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile"
            }

            $profileStatus = @{}
            $disabledProfiles = @()

            foreach ($profileName in $firewallProfiles.Keys) {
                $profilePath = $firewallProfiles[$profileName]
                $profileKey = $reg.OpenSubKey($profilePath)

                if ($profileKey) {
                    $enableFirewall = $profileKey.GetValue("EnableFirewall")
                    $profileStatus[$profileName] = if ($enableFirewall -eq 1) { "Enabled" } else { "Disabled" }

                    if ($enableFirewall -ne 1) {
                        $disabledProfiles += $profileName
                    }

                    $profileKey.Close()
                } else {
                    $profileStatus[$profileName] = "Unknown"
                    $disabledProfiles += "$profileName (Registry Key Missing)"
                }
            }

            $reg.Close()

            # Also try to check via WMI/PowerShell if available
            $wmiFirewallStatus = @{}
            try {
                # Try to get firewall profile status via WMI
                $firewallProfiles = Get-WmiObject -Class Win32_Service -ComputerName $dnsHostName -Filter "Name='MpsSvc'" -ErrorAction SilentlyContinue
                if ($firewallProfiles -and $firewallProfiles.State -ne "Running") {
                    $disabledProfiles += "Windows Firewall Service Not Running"
                }
            } catch {
                # WMI access may fail, continue with registry data
            }

            # Flag if any firewall profiles are disabled
            if ($disabledProfiles.Count -gt 0) {
                $severity = "HIGH"
                if ($disabledProfiles -contains "Domain") {
                    $severity = "CRITICAL"  # Domain profile disabled is most critical for DCs
                }

                $output += [PSCustomObject]@{
                    Label                   = 'DC with Disabled Windows Firewall'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    DomainProfile           = $profileStatus["Domain"]
                    StandardProfile         = $profileStatus["Standard"]
                    PublicProfile           = $profileStatus["Public"]
                    DisabledProfiles        = ($disabledProfiles -join ', ')
                    DisabledCount           = $disabledProfiles.Count
                    Severity                = $severity
                    Risk                    = "Unfiltered network access, increased attack surface"
                    Recommendation          = "Enable Windows Firewall on all profiles"
                }
            }
        } catch {
            # Handle remote access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check Windows Firewall on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC Firewall Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                DomainProfile           = "Access Denied"
                StandardProfile         = "Access Denied"
                PublicProfile           = "Access Denied"
                DisabledProfiles        = "Unable to verify firewall status"
                DisabledCount           = "Unknown"
                Severity                = "UNKNOWN"
                Risk                    = "Unable to verify firewall configuration"
                Recommendation          = "Manual verification required"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        $criticalCount = ($output | Where-Object { $_.Severity -eq "CRITICAL" }).Count
        $highCount = ($output | Where-Object { $_.Severity -eq "HIGH" }).Count

        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with firewall issues" -ForegroundColor Yellow
        Write-Host "  - Critical (Domain profile disabled): $criticalCount" -ForegroundColor Red
        Write-Host "  - High (Other profiles disabled): $highCount" -ForegroundColor Red
    } else {
        Write-Host 'No findings - All Domain Controllers have Windows Firewall properly enabled' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        $criticalCount = ($output | Where-Object { $_.Severity -eq "CRITICAL" }).Count
        $highCount = ($output | Where-Object { $_.Severity -eq "HIGH" }).Count

        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with firewall issues" -ForegroundColor Yellow
        Write-Host "  - Critical (Domain profile disabled): $criticalCount" -ForegroundColor Red
        Write-Host "  - High (Other profiles disabled): $highCount" -ForegroundColor Red
    } else {
        Write-Host 'No findings - All Domain Controllers have Windows Firewall properly enabled' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
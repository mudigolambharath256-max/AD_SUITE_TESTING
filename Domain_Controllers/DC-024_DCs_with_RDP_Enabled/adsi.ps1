# Check: DCs with RDP Enabled
# Category: Domain Controllers
# Severity: high
# ID: DC-024
# Requirements: None
# ============================================
# WMI: Win32_TerminalServiceSetting.AllowTSConnections
# Registry: HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\fDenyTSConnections

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + WMI + Registry
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
            # Check RDP settings via registry
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)
            $regPath = "SYSTEM\CurrentControlSet\Control\Terminal Server"
            $regKey = $reg.OpenSubKey($regPath)

            $fDenyTSConnections = $null
            if ($regKey) {
                $fDenyTSConnections = $regKey.GetValue("fDenyTSConnections")
                $regKey.Close()
            }
            $reg.Close()

            # Also check via WMI if available
            $rdpEnabled = $false
            $rdpMethod = "Registry"

            try {
                $terminalSettings = Get-WmiObject -Class Win32_TerminalServiceSetting -Namespace "root\cimv2\TerminalServices" -ComputerName $dnsHostName -ErrorAction SilentlyContinue
                if ($terminalSettings) {
                    $rdpEnabled = $terminalSettings.AllowTSConnections -eq 1
                    $rdpMethod = "WMI"
                }
            } catch {
                # Fall back to registry check
                if ($fDenyTSConnections -ne $null) {
                    $rdpEnabled = $fDenyTSConnections -eq 0
                    $rdpMethod = "Registry"
                }
            }

            # Flag if RDP is enabled on DC
            if ($rdpEnabled) {
                $output += [PSCustomObject]@{
                    Label                   = 'DC with RDP Enabled'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    RDPEnabled              = $rdpEnabled
                    DetectionMethod         = $rdpMethod
                    fDenyTSConnections      = if ($fDenyTSConnections -ne $null) { $fDenyTSConnections } else { "Not Found" }
                    Severity                = "HIGH"
                    MITRE                   = "T1021.001"
                    Risk                    = "Remote access to Domain Controller without PAW justification"
                    Recommendation          = "Disable RDP unless using Privileged Access Workstations (PAW)"
                }
            }
        } catch {
            # Handle remote access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check RDP configuration on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC RDP Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                RDPEnabled              = "Unknown"
                DetectionMethod         = "Access Denied"
                fDenyTSConnections      = "Access Denied"
                Severity                = "UNKNOWN"
                MITRE                   = "T1021.001"
                Risk                    = "Unable to verify RDP configuration"
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
                    checkid = 'DC-024'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-024_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with RDP Enabled
# Category: Domain Controllers
# Severity: high
# ID: DC-024
# Requirements: None
# ============================================
# WMI: Win32_TerminalServiceSetting.AllowTSConnections
# Registry: HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\fDenyTSConnections

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + WMI + Registry
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
            # Check RDP settings via registry
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)
            $regPath = "SYSTEM\CurrentControlSet\Control\Terminal Server"
            $regKey = $reg.OpenSubKey($regPath)

            $fDenyTSConnections = $null
            if ($regKey) {
                $fDenyTSConnections = $regKey.GetValue("fDenyTSConnections")
                $regKey.Close()
            }
            $reg.Close()

            # Also check via WMI if available
            $rdpEnabled = $false
            $rdpMethod = "Registry"

            try {
                $terminalSettings = Get-WmiObject -Class Win32_TerminalServiceSetting -Namespace "root\cimv2\TerminalServices" -ComputerName $dnsHostName -ErrorAction SilentlyContinue
                if ($terminalSettings) {
                    $rdpEnabled = $terminalSettings.AllowTSConnections -eq 1
                    $rdpMethod = "WMI"
                }
            } catch {
                # Fall back to registry check
                if ($fDenyTSConnections -ne $null) {
                    $rdpEnabled = $fDenyTSConnections -eq 0
                    $rdpMethod = "Registry"
                }
            }

            # Flag if RDP is enabled on DC
            if ($rdpEnabled) {
                $output += [PSCustomObject]@{
                    Label                   = 'DC with RDP Enabled'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    RDPEnabled              = $rdpEnabled
                    DetectionMethod         = $rdpMethod
                    fDenyTSConnections      = if ($fDenyTSConnections -ne $null) { $fDenyTSConnections } else { "Not Found" }
                    Severity                = "HIGH"
                    MITRE                   = "T1021.001"
                    Risk                    = "Remote access to Domain Controller without PAW justification"
                    Recommendation          = "Disable RDP unless using Privileged Access Workstations (PAW)"
                }
            }
        } catch {
            # Handle remote access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check RDP configuration on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC RDP Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                RDPEnabled              = "Unknown"
                DetectionMethod         = "Access Denied"
                fDenyTSConnections      = "Access Denied"
                Severity                = "UNKNOWN"
                MITRE                   = "T1021.001"
                Risk                    = "Unable to verify RDP configuration"
                Recommendation          = "Manual verification required"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with RDP enabled" -ForegroundColor Yellow
        Write-Host "Note: RDP on DCs should only be enabled with Privileged Access Workstations (PAW)" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have RDP properly disabled' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with RDP enabled" -ForegroundColor Yellow
        Write-Host "Note: RDP on DCs should only be enabled with Privileged Access Workstations (PAW)" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have RDP properly disabled' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
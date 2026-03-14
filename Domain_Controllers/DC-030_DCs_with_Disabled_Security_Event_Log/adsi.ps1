# Check: DCs with Disabled Security Event Log
# Category: Domain Controllers
# Severity: high
# ID: DC-030
# Requirements: None
# ============================================
# WMI: Get-WinEvent -ListLog Security

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + WMI/Registry
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
            # Check Security Event Log configuration via registry
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)

            $eventLogPath = "SYSTEM\CurrentControlSet\Services\EventLog\Security"
            $eventLogKey = $reg.OpenSubKey($eventLogPath)

            $maxSize = $null
            $retention = $null
            $enabled = $null

            if ($eventLogKey) {
                $maxSize = $eventLogKey.GetValue("MaxSize")
                $retention = $eventLogKey.GetValue("Retention")
                # Security log is typically always enabled, but check if it exists
                $enabled = $true
                $eventLogKey.Close()
            } else {
                $enabled = $false
            }

            $reg.Close()

            # Also try to get log info via WMI (if accessible)
            $wmiLogInfo = $null
            try {
                $wmiLogInfo = Get-WmiObject -Class Win32_NTEventlogFile -ComputerName $dnsHostName -Filter "LogfileName='Security'" -ErrorAction SilentlyContinue
            } catch {
                # WMI access may fail, continue with registry data
            }

            # Determine issues
            $issues = @()
            $hasIssues = $false

            if (-not $enabled) {
                $hasIssues = $true
                $issues += "Security Event Log not configured"
            }

            # Check max size (should be >= 200MB per STIG recommendations)
            $maxSizeMB = 0
            if ($maxSize) {
                $maxSizeMB = [math]::Round($maxSize / 1MB, 0)
                if ($maxSizeMB -lt 200) {
                    $hasIssues = $true
                    $issues += "Max size too small: ${maxSizeMB}MB (should be ≥200MB)"
                }
            } elseif ($wmiLogInfo -and $wmiLogInfo.MaxFileSize) {
                $maxSizeMB = [math]::Round($wmiLogInfo.MaxFileSize / 1MB, 0)
                if ($maxSizeMB -lt 200) {
                    $hasIssues = $true
                    $issues += "Max size too small: ${maxSizeMB}MB (should be ≥200MB)"
                }
            } else {
                $hasIssues = $true
                $issues += "Unable to determine max size"
            }

            # Check if log is full and not overwriting (retention issues)
            if ($wmiLogInfo) {
                if ($wmiLogInfo.FileSize -ge ($wmiLogInfo.MaxFileSize * 0.95)) {
                    $hasIssues = $true
                    $issues += "Log file nearly full (${wmiLogInfo.FileSize} bytes)"
                }
            }

            if ($hasIssues) {
                [PSCustomObject]@{
                    Label               = 'DC with Security Event Log Issues'
                    Name                = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName         = $dnsHostName
                    OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    LogEnabled          = $enabled
                    MaxSizeMB           = $maxSizeMB
                    RetentionDays       = if ($retention) { $retention } else { "Unknown" }
                    CurrentSizeMB       = if ($wmiLogInfo) { [math]::Round($wmiLogInfo.FileSize / 1MB, 0) } else { "Unknown" }
                    Issues              = ($issues -join '; ')
                    Severity            = if (-not $enabled) { "CRITICAL" } elseif ($maxSizeMB -lt 50) { "HIGH" } else { "MEDIUM" }
                    Risk                = "Insufficient security event logging and retention"
                }
            }
        } catch {
            # Handle remote registry access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check Security Event Log on ${dnsHostName}: $_"
            [PSCustomObject]@{
                Label               = 'DC Security Event Log Check Failed'
                Name                = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName         = $dnsHostName
                OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                LogEnabled          = "Unknown"
                MaxSizeMB           = "Access Denied"
                RetentionDays       = "Access Denied"
                CurrentSizeMB       = "Access Denied"
                Issues              = "Unable to verify Security Event Log configuration"
                Severity            = "UNKNOWN"
                Risk                = "Unable to verify security logging status"
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
                    checkid = 'DC-030'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-030_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Disabled Security Event Log
# Category: Domain Controllers
# Severity: high
# ID: DC-030
# Requirements: None
# ============================================
# WMI: Get-WinEvent -ListLog Security

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + WMI/Registry
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
            # Check Security Event Log configuration via registry
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)

            $eventLogPath = "SYSTEM\CurrentControlSet\Services\EventLog\Security"
            $eventLogKey = $reg.OpenSubKey($eventLogPath)

            $maxSize = $null
            $retention = $null
            $enabled = $null

            if ($eventLogKey) {
                $maxSize = $eventLogKey.GetValue("MaxSize")
                $retention = $eventLogKey.GetValue("Retention")
                # Security log is typically always enabled, but check if it exists
                $enabled = $true
                $eventLogKey.Close()
            } else {
                $enabled = $false
            }

            $reg.Close()

            # Also try to get log info via WMI (if accessible)
            $wmiLogInfo = $null
            try {
                $wmiLogInfo = Get-WmiObject -Class Win32_NTEventlogFile -ComputerName $dnsHostName -Filter "LogfileName='Security'" -ErrorAction SilentlyContinue
            } catch {
                # WMI access may fail, continue with registry data
            }

            # Determine issues
            $issues = @()
            $hasIssues = $false

            if (-not $enabled) {
                $hasIssues = $true
                $issues += "Security Event Log not configured"
            }

            # Check max size (should be >= 200MB per STIG recommendations)
            $maxSizeMB = 0
            if ($maxSize) {
                $maxSizeMB = [math]::Round($maxSize / 1MB, 0)
                if ($maxSizeMB -lt 200) {
                    $hasIssues = $true
                    $issues += "Max size too small: ${maxSizeMB}MB (should be ≥200MB)"
                }
            } elseif ($wmiLogInfo -and $wmiLogInfo.MaxFileSize) {
                $maxSizeMB = [math]::Round($wmiLogInfo.MaxFileSize / 1MB, 0)
                if ($maxSizeMB -lt 200) {
                    $hasIssues = $true
                    $issues += "Max size too small: ${maxSizeMB}MB (should be ≥200MB)"
                }
            } else {
                $hasIssues = $true
                $issues += "Unable to determine max size"
            }

            # Check if log is full and not overwriting (retention issues)
            if ($wmiLogInfo) {
                if ($wmiLogInfo.FileSize -ge ($wmiLogInfo.MaxFileSize * 0.95)) {
                    $hasIssues = $true
                    $issues += "Log file nearly full (${wmiLogInfo.FileSize} bytes)"
                }
            }

            if ($hasIssues) {
                [PSCustomObject]@{
                    Label               = 'DC with Security Event Log Issues'
                    Name                = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName         = $dnsHostName
                    OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    LogEnabled          = $enabled
                    MaxSizeMB           = $maxSizeMB
                    RetentionDays       = if ($retention) { $retention } else { "Unknown" }
                    CurrentSizeMB       = if ($wmiLogInfo) { [math]::Round($wmiLogInfo.FileSize / 1MB, 0) } else { "Unknown" }
                    Issues              = ($issues -join '; ')
                    Severity            = if (-not $enabled) { "CRITICAL" } elseif ($maxSizeMB -lt 50) { "HIGH" } else { "MEDIUM" }
                    Risk                = "Insufficient security event logging and retention"
                }
            }
        } catch {
            # Handle remote registry access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check Security Event Log on ${dnsHostName}: $_"
            [PSCustomObject]@{
                Label               = 'DC Security Event Log Check Failed'
                Name                = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName         = $dnsHostName
                OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                LogEnabled          = "Unknown"
                MaxSizeMB           = "Access Denied"
                RetentionDays       = "Access Denied"
                CurrentSizeMB       = "Access Denied"
                Issues              = "Unable to verify Security Event Log configuration"
                Severity            = "UNKNOWN"
                Risk                = "Unable to verify security logging status"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with Security Event Log issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper Security Event Log configuration' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with Security Event Log issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper Security Event Log configuration' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
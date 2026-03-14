# Check: DCs with Cached Credentials Excessive
# Category: Domain Controllers
# Severity: high
# ID: DC-034
# Requirements: None
# ============================================
# Registry: HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\CachedLogonsCount

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + Registry
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

        if ($dnsHostName -eq 'N/A') {
            Write-Warning "Skipping DC with no DNS hostname: $($p['name'][0])"
            continue
        }

        try {
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)

            # Check cached logons count
            $winlogonPath = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
            $winlogonKey = $reg.OpenSubKey($winlogonPath)
            $cachedLogonsCount = $null
            if ($winlogonKey) {
                $cachedLogonsCount = $winlogonKey.GetValue("CachedLogonsCount")
                $winlogonKey.Close()
            }

            # Check MSV1_0 cached credentials
            $lsaPath = "SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0"
            $lsaKey = $reg.OpenSubKey($lsaPath)
            $cachedCredentials = $null
            if ($lsaKey) {
                $cachedCredentials = $lsaKey.GetValue("CachedLogonsCount")
                $lsaKey.Close()
            }

            $reg.Close()

            $issues = @()
            $severity = "HIGH"

            # DCs should never cache interactive logons (should be 0)
            if ($cachedLogonsCount -ne $null -and $cachedLogonsCount -gt 0) {
                $issues += "Winlogon CachedLogonsCount set to $cachedLogonsCount (should be 0 for DCs)"
            }

            if ($cachedCredentials -ne $null -and $cachedCredentials -gt 0) {
                $issues += "LSA MSV1_0 CachedLogonsCount set to $cachedCredentials (should be 0 for DCs)"
            }

            # If both are null, check default behavior
            if ($cachedLogonsCount -eq $null -and $cachedCredentials -eq $null) {
                $issues += "Cached logons count not explicitly configured (default may allow caching)"
                $severity = "MEDIUM"
            }

            if ($issues.Count -gt 0) {
                $output += [PSCustomObject]@{
                    Label                   = 'DC with Excessive Cached Credentials'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    WinlogonCachedCount     = if ($cachedLogonsCount -ne $null) { $cachedLogonsCount } else { "Not Set" }
                    LSACachedCount          = if ($cachedCredentials -ne $null) { $cachedCredentials } else { "Not Set" }
                    Issues                  = ($issues -join '; ')
                    IssueCount              = $issues.Count
                    Severity                = $severity
                    Risk                    = "Cached credentials on DC vulnerable to offline attacks"
                    Recommendation          = "Set CachedLogonsCount to 0 on Domain Controllers"
                }
            }
        } catch {
            Write-Warning "Unable to check cached credentials on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC Cached Credentials Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                WinlogonCachedCount     = "Access Denied"
                LSACachedCount          = "Access Denied"
                Issues                  = "Unable to verify cached credentials configuration"
                IssueCount              = "Unknown"
                Severity                = "UNKNOWN"
                Risk                    = "Unable to verify credential caching status"
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
                    checkid = 'DC-034'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-034_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Cached Credentials Excessive
# Category: Domain Controllers
# Severity: high
# ID: DC-034
# Requirements: None
# ============================================
# Registry: HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\CachedLogonsCount

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + Registry
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

        if ($dnsHostName -eq 'N/A') {
            Write-Warning "Skipping DC with no DNS hostname: $($p['name'][0])"
            continue
        }

        try {
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)

            # Check cached logons count
            $winlogonPath = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
            $winlogonKey = $reg.OpenSubKey($winlogonPath)
            $cachedLogonsCount = $null
            if ($winlogonKey) {
                $cachedLogonsCount = $winlogonKey.GetValue("CachedLogonsCount")
                $winlogonKey.Close()
            }

            # Check MSV1_0 cached credentials
            $lsaPath = "SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0"
            $lsaKey = $reg.OpenSubKey($lsaPath)
            $cachedCredentials = $null
            if ($lsaKey) {
                $cachedCredentials = $lsaKey.GetValue("CachedLogonsCount")
                $lsaKey.Close()
            }

            $reg.Close()

            $issues = @()
            $severity = "HIGH"

            # DCs should never cache interactive logons (should be 0)
            if ($cachedLogonsCount -ne $null -and $cachedLogonsCount -gt 0) {
                $issues += "Winlogon CachedLogonsCount set to $cachedLogonsCount (should be 0 for DCs)"
            }

            if ($cachedCredentials -ne $null -and $cachedCredentials -gt 0) {
                $issues += "LSA MSV1_0 CachedLogonsCount set to $cachedCredentials (should be 0 for DCs)"
            }

            # If both are null, check default behavior
            if ($cachedLogonsCount -eq $null -and $cachedCredentials -eq $null) {
                $issues += "Cached logons count not explicitly configured (default may allow caching)"
                $severity = "MEDIUM"
            }

            if ($issues.Count -gt 0) {
                $output += [PSCustomObject]@{
                    Label                   = 'DC with Excessive Cached Credentials'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    WinlogonCachedCount     = if ($cachedLogonsCount -ne $null) { $cachedLogonsCount } else { "Not Set" }
                    LSACachedCount          = if ($cachedCredentials -ne $null) { $cachedCredentials } else { "Not Set" }
                    Issues                  = ($issues -join '; ')
                    IssueCount              = $issues.Count
                    Severity                = $severity
                    Risk                    = "Cached credentials on DC vulnerable to offline attacks"
                    Recommendation          = "Set CachedLogonsCount to 0 on Domain Controllers"
                }
            }
        } catch {
            Write-Warning "Unable to check cached credentials on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC Cached Credentials Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                WinlogonCachedCount     = "Access Denied"
                LSACachedCount          = "Access Denied"
                Issues                  = "Unable to verify cached credentials configuration"
                IssueCount              = "Unknown"
                Severity                = "UNKNOWN"
                Risk                    = "Unable to verify credential caching status"
                Recommendation          = "Manual verification required"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with cached credential issues" -ForegroundColor Yellow
        Write-Host "Note: DCs should never cache interactive logons as they authenticate against AD directly" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper credential caching configuration' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with cached credential issues" -ForegroundColor Yellow
        Write-Host "Note: DCs should never cache interactive logons as they authenticate against AD directly" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper credential caching configuration' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
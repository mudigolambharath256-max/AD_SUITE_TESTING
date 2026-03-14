# Check: DCs with Insecure Share Permissions
# Category: Domain Controllers
# Severity: high
# ID: DC-029
# Requirements: None
# ============================================
# WMI: SELECT Name,Path,Description FROM Win32_Share

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
            # Get all shares via WMI
            $shares = Get-WmiObject -Class Win32_Share -ComputerName $dnsHostName -ErrorAction Stop

            foreach ($share in $shares) {
                # Skip system shares that are expected
                if ($share.Name -match '^[A-Z]\$$|^ADMIN\$$|^IPC\$$') {
                    continue
                }

                try {
                    # Check share permissions using Get-SmbShareAccess (if available) or WMI
                    $sharePermissions = @()
                    $hasInsecurePermissions = $false
                    $issues = @()

                    # For SYSVOL and NETLOGON, check for write permissions to Everyone
                    if ($share.Name -eq "SYSVOL" -or $share.Name -eq "NETLOGON") {
                        try {
                            # Try to get SMB share access (PowerShell 3.0+)
                            $smbAccess = Get-SmbShareAccess -Name $share.Name -CimSession $dnsHostName -ErrorAction SilentlyContinue

                            foreach ($access in $smbAccess) {
                                if ($access.AccountName -eq "Everyone" -and ($access.AccessRight -eq "Full" -or $access.AccessRight -eq "Change")) {
                                    $hasInsecurePermissions = $true
                                    $issues += "$($share.Name) has $($access.AccessRight) access for Everyone"
                                }
                            }
                        } catch {
                            # Fallback: Flag as potential issue if we can't check permissions
                            $issues += "$($share.Name) permissions could not be verified"
                        }
                    } else {
                        # Non-standard share on DC
                        $hasInsecurePermissions = $true
                        $issues += "Non-standard share '$($share.Name)' found on DC"
                    }

                    if ($hasInsecurePermissions -or $issues.Count -gt 0) {
                        $output += [PSCustomObject]@{
                            Label               = 'DC with Insecure Share Permissions'
                            DCName              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                            DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                            DNSHostName         = $dnsHostName
                            OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                            ShareName           = $share.Name
                            SharePath           = $share.Path
                            ShareDescription    = $share.Description
                            Issues              = ($issues -join '; ')
                            Severity            = if ($share.Name -eq "SYSVOL" -or $share.Name -eq "NETLOGON") { "HIGH" } else { "MEDIUM" }
                            Risk                = if ($share.Name -eq "SYSVOL" -or $share.Name -eq "NETLOGON") { "Critical domain shares with insecure permissions" } else { "Unauthorized share on Domain Controller" }
                        }
                    }
                } catch {
                    Write-Warning "Unable to check permissions for share '$($share.Name)' on ${dnsHostName}: $_"
                }
            }
        } catch {
            # Handle WMI access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to enumerate shares on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label               = 'DC Share Check Failed'
                DCName              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName         = $dnsHostName
                OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                ShareName           = "Access Denied"
                SharePath           = "WMI Access Failed"
                ShareDescription    = "Unable to enumerate shares"
                Issues              = "Unable to verify share permissions"
                Severity            = "UNKNOWN"
                Risk                = "Unable to verify share security"
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
                    checkid = 'DC-029'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-029_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Insecure Share Permissions
# Category: Domain Controllers
# Severity: high
# ID: DC-029
# Requirements: None
# ============================================
# WMI: SELECT Name,Path,Description FROM Win32_Share

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
            # Get all shares via WMI
            $shares = Get-WmiObject -Class Win32_Share -ComputerName $dnsHostName -ErrorAction Stop

            foreach ($share in $shares) {
                # Skip system shares that are expected
                if ($share.Name -match '^[A-Z]\$$|^ADMIN\$$|^IPC\$$') {
                    continue
                }

                try {
                    # Check share permissions using Get-SmbShareAccess (if available) or WMI
                    $sharePermissions = @()
                    $hasInsecurePermissions = $false
                    $issues = @()

                    # For SYSVOL and NETLOGON, check for write permissions to Everyone
                    if ($share.Name -eq "SYSVOL" -or $share.Name -eq "NETLOGON") {
                        try {
                            # Try to get SMB share access (PowerShell 3.0+)
                            $smbAccess = Get-SmbShareAccess -Name $share.Name -CimSession $dnsHostName -ErrorAction SilentlyContinue

                            foreach ($access in $smbAccess) {
                                if ($access.AccountName -eq "Everyone" -and ($access.AccessRight -eq "Full" -or $access.AccessRight -eq "Change")) {
                                    $hasInsecurePermissions = $true
                                    $issues += "$($share.Name) has $($access.AccessRight) access for Everyone"
                                }
                            }
                        } catch {
                            # Fallback: Flag as potential issue if we can't check permissions
                            $issues += "$($share.Name) permissions could not be verified"
                        }
                    } else {
                        # Non-standard share on DC
                        $hasInsecurePermissions = $true
                        $issues += "Non-standard share '$($share.Name)' found on DC"
                    }

                    if ($hasInsecurePermissions -or $issues.Count -gt 0) {
                        $output += [PSCustomObject]@{
                            Label               = 'DC with Insecure Share Permissions'
                            DCName              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                            DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                            DNSHostName         = $dnsHostName
                            OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                            ShareName           = $share.Name
                            SharePath           = $share.Path
                            ShareDescription    = $share.Description
                            Issues              = ($issues -join '; ')
                            Severity            = if ($share.Name -eq "SYSVOL" -or $share.Name -eq "NETLOGON") { "HIGH" } else { "MEDIUM" }
                            Risk                = if ($share.Name -eq "SYSVOL" -or $share.Name -eq "NETLOGON") { "Critical domain shares with insecure permissions" } else { "Unauthorized share on Domain Controller" }
                        }
                    }
                } catch {
                    Write-Warning "Unable to check permissions for share '$($share.Name)' on ${dnsHostName}: $_"
                }
            }
        } catch {
            # Handle WMI access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to enumerate shares on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label               = 'DC Share Check Failed'
                DCName              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName         = $dnsHostName
                OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                ShareName           = "Access Denied"
                SharePath           = "WMI Access Failed"
                ShareDescription    = "Unable to enumerate shares"
                Issues              = "Unable to verify share permissions"
                Severity            = "UNKNOWN"
                Risk                = "Unable to verify share security"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        $highRisk = ($output | Where-Object { $_.Severity -eq "HIGH" }).Count
        $mediumRisk = ($output | Where-Object { $_.Severity -eq "MEDIUM" }).Count

        Write-Host "`nSummary: Found $($output.Count) share permission issues on Domain Controllers" -ForegroundColor Yellow
        Write-Host "  - High Risk (SYSVOL/NETLOGON issues): $highRisk" -ForegroundColor Red
        Write-Host "  - Medium Risk (Non-standard shares): $mediumRisk" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controller shares have proper permissions' -ForegroundColor Green
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

        Write-Host "`nSummary: Found $($output.Count) share permission issues on Domain Controllers" -ForegroundColor Yellow
        Write-Host "  - High Risk (SYSVOL/NETLOGON issues): $highRisk" -ForegroundColor Red
        Write-Host "  - Medium Risk (Non-standard shares): $mediumRisk" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controller shares have proper permissions' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
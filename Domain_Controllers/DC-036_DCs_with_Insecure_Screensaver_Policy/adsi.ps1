# Check: DCs with Insecure Screensaver Policy
# Category: Domain Controllers
# Severity: low
# ID: DC-036
# Requirements: None
# ============================================
# Registry: HKCU\Control Panel\Desktop

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Low
# DataSource          : LDAP + Registry
# FalsePositiveRisk   : High
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
            # Check screensaver policy via registry (system context and default user)
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)

            # Check default user profile settings
            $defaultUserPath = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-18"
            $defaultUserKey = $reg.OpenSubKey($defaultUserPath)

            # Check system-wide screensaver policy
            $policyPath = "SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop"
            $policyKey = $reg.OpenSubKey($policyPath)

            $screenSaverIsSecure = $null
            $screenSaveTimeOut = $null
            $screenSaverExe = $null
            $policyScreenSaverIsSecure = $null
            $policyScreenSaveTimeOut = $null

            if ($policyKey) {
                $policyScreenSaverIsSecure = $policyKey.GetValue("ScreenSaverIsSecure")
                $policyScreenSaveTimeOut = $policyKey.GetValue("ScreenSaveTimeOut")
                $policyKey.Close()
            }

            # Also check current user settings (may not be applicable for servers)
            try {
                $currentUserReg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('CurrentUser', $dnsHostName)
                $desktopPath = "Control Panel\Desktop"
                $desktopKey = $currentUserReg.OpenSubKey($desktopPath)

                if ($desktopKey) {
                    $screenSaverIsSecure = $desktopKey.GetValue("ScreenSaverIsSecure")
                    $screenSaveTimeOut = $desktopKey.GetValue("ScreenSaveTimeOut")
                    $screenSaverExe = $desktopKey.GetValue("SCRNSAVE.EXE")
                    $desktopKey.Close()
                }
                $currentUserReg.Close()
            } catch {
                # Current user registry may not be accessible
            }

            $reg.Close()

            $issues = @()
            $severity = "LOW"

            # Note: DCs are servers and should not have interactive desktop sessions
            # This check is primarily informational

            if ($screenSaverIsSecure -eq 0 -or $policyScreenSaverIsSecure -eq 0) {
                $issues += "Screensaver not configured to lock workstation"
                $severity = "MEDIUM"
            }

            if ($screenSaveTimeOut -ne $null -and $screenSaveTimeOut -gt 900) {
                $issues += "Screensaver timeout > 15 minutes ($screenSaveTimeOut seconds)"
            }

            if ($policyScreenSaveTimeOut -ne $null -and $policyScreenSaveTimeOut -gt 900) {
                $issues += "Policy screensaver timeout > 15 minutes ($policyScreenSaveTimeOut seconds)"
            }

            if ($screenSaverExe -eq $null -or $screenSaverExe -eq "") {
                $issues += "No screensaver configured"
            }

            # Add compensating control note for servers
            if ($issues.Count -gt 0) {
                $issues += "NOTE: DCs are servers - interactive desktop sessions should be minimal"

                $output += [PSCustomObject]@{
                    Label                       = 'DC with Insecure Screensaver Policy'
                    Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName                 = $dnsHostName
                    OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    ScreenSaverIsSecure         = if ($screenSaverIsSecure -ne $null) { $screenSaverIsSecure } else { "Not Set" }
                    ScreenSaveTimeOut           = if ($screenSaveTimeOut -ne $null) { $screenSaveTimeOut } else { "Not Set" }
                    ScreenSaverExe              = if ($screenSaverExe -ne $null) { $screenSaverExe } else { "Not Set" }
                    PolicyScreenSaverIsSecure   = if ($policyScreenSaverIsSecure -ne $null) { $policyScreenSaverIsSecure } else { "Not Set" }
                    PolicyScreenSaveTimeOut     = if ($policyScreenSaveTimeOut -ne $null) { $policyScreenSaveTimeOut } else { "Not Set" }
                    Issues                      = ($issues -join '; ')
                    IssueCount                  = $issues.Count - 1  # Exclude the NOTE
                    Severity                    = $severity
                    Risk                        = "Unattended console access (low risk for servers)"
                    Recommendation              = "Configure screensaver policy or eliminate interactive sessions"
                    CompensatingControl         = "DCs should not have regular interactive desktop sessions"
                }
            }
        } catch {
            Write-Warning "Unable to check screensaver policy on ${dnsHostName}: $_"
            # Don't report access failures for this low-severity check
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
                    checkid = 'DC-036'
                    severity = 'low'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-036_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Insecure Screensaver Policy
# Category: Domain Controllers
# Severity: low
# ID: DC-036
# Requirements: None
# ============================================
# Registry: HKCU\Control Panel\Desktop

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Low
# DataSource          : LDAP + Registry
# FalsePositiveRisk   : High
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
            # Check screensaver policy via registry (system context and default user)
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)

            # Check default user profile settings
            $defaultUserPath = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-18"
            $defaultUserKey = $reg.OpenSubKey($defaultUserPath)

            # Check system-wide screensaver policy
            $policyPath = "SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop"
            $policyKey = $reg.OpenSubKey($policyPath)

            $screenSaverIsSecure = $null
            $screenSaveTimeOut = $null
            $screenSaverExe = $null
            $policyScreenSaverIsSecure = $null
            $policyScreenSaveTimeOut = $null

            if ($policyKey) {
                $policyScreenSaverIsSecure = $policyKey.GetValue("ScreenSaverIsSecure")
                $policyScreenSaveTimeOut = $policyKey.GetValue("ScreenSaveTimeOut")
                $policyKey.Close()
            }

            # Also check current user settings (may not be applicable for servers)
            try {
                $currentUserReg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('CurrentUser', $dnsHostName)
                $desktopPath = "Control Panel\Desktop"
                $desktopKey = $currentUserReg.OpenSubKey($desktopPath)

                if ($desktopKey) {
                    $screenSaverIsSecure = $desktopKey.GetValue("ScreenSaverIsSecure")
                    $screenSaveTimeOut = $desktopKey.GetValue("ScreenSaveTimeOut")
                    $screenSaverExe = $desktopKey.GetValue("SCRNSAVE.EXE")
                    $desktopKey.Close()
                }
                $currentUserReg.Close()
            } catch {
                # Current user registry may not be accessible
            }

            $reg.Close()

            $issues = @()
            $severity = "LOW"

            # Note: DCs are servers and should not have interactive desktop sessions
            # This check is primarily informational

            if ($screenSaverIsSecure -eq 0 -or $policyScreenSaverIsSecure -eq 0) {
                $issues += "Screensaver not configured to lock workstation"
                $severity = "MEDIUM"
            }

            if ($screenSaveTimeOut -ne $null -and $screenSaveTimeOut -gt 900) {
                $issues += "Screensaver timeout > 15 minutes ($screenSaveTimeOut seconds)"
            }

            if ($policyScreenSaveTimeOut -ne $null -and $policyScreenSaveTimeOut -gt 900) {
                $issues += "Policy screensaver timeout > 15 minutes ($policyScreenSaveTimeOut seconds)"
            }

            if ($screenSaverExe -eq $null -or $screenSaverExe -eq "") {
                $issues += "No screensaver configured"
            }

            # Add compensating control note for servers
            if ($issues.Count -gt 0) {
                $issues += "NOTE: DCs are servers - interactive desktop sessions should be minimal"

                $output += [PSCustomObject]@{
                    Label                       = 'DC with Insecure Screensaver Policy'
                    Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName                 = $dnsHostName
                    OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    ScreenSaverIsSecure         = if ($screenSaverIsSecure -ne $null) { $screenSaverIsSecure } else { "Not Set" }
                    ScreenSaveTimeOut           = if ($screenSaveTimeOut -ne $null) { $screenSaveTimeOut } else { "Not Set" }
                    ScreenSaverExe              = if ($screenSaverExe -ne $null) { $screenSaverExe } else { "Not Set" }
                    PolicyScreenSaverIsSecure   = if ($policyScreenSaverIsSecure -ne $null) { $policyScreenSaverIsSecure } else { "Not Set" }
                    PolicyScreenSaveTimeOut     = if ($policyScreenSaveTimeOut -ne $null) { $policyScreenSaveTimeOut } else { "Not Set" }
                    Issues                      = ($issues -join '; ')
                    IssueCount                  = $issues.Count - 1  # Exclude the NOTE
                    Severity                    = $severity
                    Risk                        = "Unattended console access (low risk for servers)"
                    Recommendation              = "Configure screensaver policy or eliminate interactive sessions"
                    CompensatingControl         = "DCs should not have regular interactive desktop sessions"
                }
            }
        } catch {
            Write-Warning "Unable to check screensaver policy on ${dnsHostName}: $_"
            # Don't report access failures for this low-severity check
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with screensaver policy issues" -ForegroundColor Yellow
        Write-Host "Note: This is a low-severity check. DCs should not have regular interactive sessions." -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - Domain Controller screensaver policies appear adequate' -ForegroundColor Green
        Write-Host "Note: DCs should primarily operate without interactive desktop sessions." -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with screensaver policy issues" -ForegroundColor Yellow
        Write-Host "Note: This is a low-severity check. DCs should not have regular interactive sessions." -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - Domain Controller screensaver policies appear adequate' -ForegroundColor Green
        Write-Host "Note: DCs should primarily operate without interactive desktop sessions." -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
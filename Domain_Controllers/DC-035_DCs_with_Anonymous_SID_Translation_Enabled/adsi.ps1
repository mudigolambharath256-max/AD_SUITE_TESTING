# Check: DCs with Anonymous SID Translation Enabled
# Category: Domain Controllers
# Severity: high
# ID: DC-035
# Requirements: None
# ============================================
# Registry: HKLM\SYSTEM\CurrentControlSet\Control\Lsa

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

            # Check LSA anonymous access settings
            $lsaPath = "SYSTEM\CurrentControlSet\Control\Lsa"
            $lsaKey = $reg.OpenSubKey($lsaPath)

            $turnOffAnonymousBlock = $null
            $anonymousNameLookup = $null
            $everyoneIncludesAnonymous = $null
            $restrictAnonymous = $null
            $restrictAnonymousSAM = $null

            if ($lsaKey) {
                $turnOffAnonymousBlock = $lsaKey.GetValue("TurnOffAnonymousBlock")
                $anonymousNameLookup = $lsaKey.GetValue("AnonymousNameLookup")
                $everyoneIncludesAnonymous = $lsaKey.GetValue("EveryoneIncludesAnonymous")
                $restrictAnonymous = $lsaKey.GetValue("RestrictAnonymous")
                $restrictAnonymousSAM = $lsaKey.GetValue("RestrictAnonymousSAM")
                $lsaKey.Close()
            }

            $reg.Close()

            $issues = @()
            $severity = "HIGH"

            # Check for insecure anonymous access settings
            if ($everyoneIncludesAnonymous -eq 1) {
                $issues += "EveryoneIncludesAnonymous=1 (Everyone group includes anonymous users)"
                $severity = "CRITICAL"
            }

            if ($anonymousNameLookup -eq 1) {
                $issues += "AnonymousNameLookup=1 (Anonymous users can perform SID/name translation)"
                $severity = "HIGH"
            }

            if ($turnOffAnonymousBlock -eq 1) {
                $issues += "TurnOffAnonymousBlock=1 (Anonymous access blocking disabled)"
                $severity = "HIGH"
            }

            if ($restrictAnonymous -ne $null -and $restrictAnonymous -lt 2) {
                $restrictLevel = switch ($restrictAnonymous) {
                    0 { "None" }
                    1 { "No SAM/LSA enumeration" }
                    2 { "No anonymous access" }
                    default { "Unknown" }
                }
                $issues += "RestrictAnonymous=$restrictAnonymous ($restrictLevel) - should be 2"
            }

            if ($restrictAnonymousSAM -ne 1) {
                $issues += "RestrictAnonymousSAM not set to 1 (SAM enumeration may be allowed)"
            }

            # Check if no restrictions are configured (default allows some anonymous access)
            if ($restrictAnonymous -eq $null -and $everyoneIncludesAnonymous -eq $null -and $anonymousNameLookup -eq $null) {
                $issues += "No explicit anonymous access restrictions configured (defaults may allow access)"
                $severity = "MEDIUM"
            }

            if ($issues.Count -gt 0) {
                $output += [PSCustomObject]@{
                    Label                       = 'DC with Anonymous SID Translation Enabled'
                    Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName                 = $dnsHostName
                    OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    EveryoneIncludesAnonymous   = if ($everyoneIncludesAnonymous -ne $null) { $everyoneIncludesAnonymous } else { "Not Set" }
                    AnonymousNameLookup         = if ($anonymousNameLookup -ne $null) { $anonymousNameLookup } else { "Not Set" }
                    TurnOffAnonymousBlock       = if ($turnOffAnonymousBlock -ne $null) { $turnOffAnonymousBlock } else { "Not Set" }
                    RestrictAnonymous           = if ($restrictAnonymous -ne $null) { $restrictAnonymous } else { "Not Set" }
                    RestrictAnonymousSAM        = if ($restrictAnonymousSAM -ne $null) { $restrictAnonymousSAM } else { "Not Set" }
                    Issues                      = ($issues -join '; ')
                    IssueCount                  = $issues.Count
                    Severity                    = $severity
                    MITRE                       = "T1078.002"
                    Risk                        = "Anonymous enumeration, SID/name translation attacks"
                    Recommendation              = "Disable anonymous access and SID translation"
                }
            }
        } catch {
            Write-Warning "Unable to check anonymous access settings on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                       = 'DC Anonymous Access Check Failed'
                Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName                 = $dnsHostName
                OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                EveryoneIncludesAnonymous   = "Access Denied"
                AnonymousNameLookup         = "Access Denied"
                TurnOffAnonymousBlock       = "Access Denied"
                RestrictAnonymous           = "Access Denied"
                RestrictAnonymousSAM        = "Access Denied"
                Issues                      = "Unable to verify anonymous access configuration"
                IssueCount                  = "Unknown"
                Severity                    = "UNKNOWN"
                MITRE                       = "T1078.002"
                Risk                        = "Unable to verify anonymous access restrictions"
                Recommendation              = "Manual verification required"
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
                    checkid = 'DC-035'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-035_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Anonymous SID Translation Enabled
# Category: Domain Controllers
# Severity: high
# ID: DC-035
# Requirements: None
# ============================================
# Registry: HKLM\SYSTEM\CurrentControlSet\Control\Lsa

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

            # Check LSA anonymous access settings
            $lsaPath = "SYSTEM\CurrentControlSet\Control\Lsa"
            $lsaKey = $reg.OpenSubKey($lsaPath)

            $turnOffAnonymousBlock = $null
            $anonymousNameLookup = $null
            $everyoneIncludesAnonymous = $null
            $restrictAnonymous = $null
            $restrictAnonymousSAM = $null

            if ($lsaKey) {
                $turnOffAnonymousBlock = $lsaKey.GetValue("TurnOffAnonymousBlock")
                $anonymousNameLookup = $lsaKey.GetValue("AnonymousNameLookup")
                $everyoneIncludesAnonymous = $lsaKey.GetValue("EveryoneIncludesAnonymous")
                $restrictAnonymous = $lsaKey.GetValue("RestrictAnonymous")
                $restrictAnonymousSAM = $lsaKey.GetValue("RestrictAnonymousSAM")
                $lsaKey.Close()
            }

            $reg.Close()

            $issues = @()
            $severity = "HIGH"

            # Check for insecure anonymous access settings
            if ($everyoneIncludesAnonymous -eq 1) {
                $issues += "EveryoneIncludesAnonymous=1 (Everyone group includes anonymous users)"
                $severity = "CRITICAL"
            }

            if ($anonymousNameLookup -eq 1) {
                $issues += "AnonymousNameLookup=1 (Anonymous users can perform SID/name translation)"
                $severity = "HIGH"
            }

            if ($turnOffAnonymousBlock -eq 1) {
                $issues += "TurnOffAnonymousBlock=1 (Anonymous access blocking disabled)"
                $severity = "HIGH"
            }

            if ($restrictAnonymous -ne $null -and $restrictAnonymous -lt 2) {
                $restrictLevel = switch ($restrictAnonymous) {
                    0 { "None" }
                    1 { "No SAM/LSA enumeration" }
                    2 { "No anonymous access" }
                    default { "Unknown" }
                }
                $issues += "RestrictAnonymous=$restrictAnonymous ($restrictLevel) - should be 2"
            }

            if ($restrictAnonymousSAM -ne 1) {
                $issues += "RestrictAnonymousSAM not set to 1 (SAM enumeration may be allowed)"
            }

            # Check if no restrictions are configured (default allows some anonymous access)
            if ($restrictAnonymous -eq $null -and $everyoneIncludesAnonymous -eq $null -and $anonymousNameLookup -eq $null) {
                $issues += "No explicit anonymous access restrictions configured (defaults may allow access)"
                $severity = "MEDIUM"
            }

            if ($issues.Count -gt 0) {
                $output += [PSCustomObject]@{
                    Label                       = 'DC with Anonymous SID Translation Enabled'
                    Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName                 = $dnsHostName
                    OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    EveryoneIncludesAnonymous   = if ($everyoneIncludesAnonymous -ne $null) { $everyoneIncludesAnonymous } else { "Not Set" }
                    AnonymousNameLookup         = if ($anonymousNameLookup -ne $null) { $anonymousNameLookup } else { "Not Set" }
                    TurnOffAnonymousBlock       = if ($turnOffAnonymousBlock -ne $null) { $turnOffAnonymousBlock } else { "Not Set" }
                    RestrictAnonymous           = if ($restrictAnonymous -ne $null) { $restrictAnonymous } else { "Not Set" }
                    RestrictAnonymousSAM        = if ($restrictAnonymousSAM -ne $null) { $restrictAnonymousSAM } else { "Not Set" }
                    Issues                      = ($issues -join '; ')
                    IssueCount                  = $issues.Count
                    Severity                    = $severity
                    MITRE                       = "T1078.002"
                    Risk                        = "Anonymous enumeration, SID/name translation attacks"
                    Recommendation              = "Disable anonymous access and SID translation"
                }
            }
        } catch {
            Write-Warning "Unable to check anonymous access settings on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                       = 'DC Anonymous Access Check Failed'
                Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName                 = $dnsHostName
                OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                EveryoneIncludesAnonymous   = "Access Denied"
                AnonymousNameLookup         = "Access Denied"
                TurnOffAnonymousBlock       = "Access Denied"
                RestrictAnonymous           = "Access Denied"
                RestrictAnonymousSAM        = "Access Denied"
                Issues                      = "Unable to verify anonymous access configuration"
                IssueCount                  = "Unknown"
                Severity                    = "UNKNOWN"
                MITRE                       = "T1078.002"
                Risk                        = "Unable to verify anonymous access restrictions"
                Recommendation              = "Manual verification required"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with anonymous access issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper anonymous access restrictions' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with anonymous access issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper anonymous access restrictions' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
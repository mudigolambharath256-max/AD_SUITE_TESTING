# Check: DCs with Local Admin Accounts
# Category: Domain Controllers
# Severity: high
# ID: DC-021
# Requirements: None
# ============================================
# WMI: SELECT * FROM Win32_UserAccount WHERE LocalAccount=True

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
            # Check for local user accounts via WMI
            $localUsers = Get-WmiObject -Class Win32_UserAccount -ComputerName $dnsHostName -Filter "LocalAccount=True" -ErrorAction Stop

            foreach ($user in $localUsers) {
                # Flag enabled local accounts beyond built-in Administrator (SID -500) and Guest (SID -501)
                $sidParts = $user.SID.Split('-')
                $rid = [int]$sidParts[-1]

                # Check if this is a concerning local account
                $isConcerning = $false
                $accountType = "Unknown"
                $risk = "Unknown"

                if ($rid -eq 500) {
                    $accountType = "Built-in Administrator"
                    if ($user.Disabled -eq $false) {
                        $isConcerning = $true
                        $risk = "Built-in Administrator account is enabled"
                    }
                } elseif ($rid -eq 501) {
                    $accountType = "Built-in Guest"
                    if ($user.Disabled -eq $false) {
                        $isConcerning = $true
                        $risk = "Built-in Guest account is enabled"
                    }
                } elseif ($rid -ge 1000) {
                    $accountType = "Custom Local Account"
                    $isConcerning = $true
                    $risk = "Custom local account on DC (DCs should not have local accounts)"
                }

                if ($isConcerning) {
                    $output += [PSCustomObject]@{
                        Label               = 'DC with Local Admin Account'
                        DCName              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                        DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                        DNSHostName         = $dnsHostName
                        OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                        LocalAccountName    = $user.Name
                        LocalAccountSID     = $user.SID
                        AccountType         = $accountType
                        Disabled            = $user.Disabled
                        Description         = $user.Description
                        LastLogin           = $user.LastLogin
                        Risk                = $risk
                        Severity            = if ($rid -ge 1000) { "HIGH" } else { "MEDIUM" }
                    }
                }
            }
        } catch {
            # Handle WMI access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check local accounts on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label               = 'DC Local Account Check Failed'
                DCName              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName         = $dnsHostName
                OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                LocalAccountName    = "Access Denied"
                LocalAccountSID     = "Access Denied"
                AccountType         = "Unknown"
                Disabled            = "Unknown"
                Description         = "WMI Access Failed"
                LastLogin           = "Unknown"
                Risk                = "Unable to verify local account status"
                Severity            = "UNKNOWN"
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
                    checkid = 'DC-021'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-021_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Local Admin Accounts
# Category: Domain Controllers
# Severity: high
# ID: DC-021
# Requirements: None
# ============================================
# WMI: SELECT * FROM Win32_UserAccount WHERE LocalAccount=True

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
            # Check for local user accounts via WMI
            $localUsers = Get-WmiObject -Class Win32_UserAccount -ComputerName $dnsHostName -Filter "LocalAccount=True" -ErrorAction Stop

            foreach ($user in $localUsers) {
                # Flag enabled local accounts beyond built-in Administrator (SID -500) and Guest (SID -501)
                $sidParts = $user.SID.Split('-')
                $rid = [int]$sidParts[-1]

                # Check if this is a concerning local account
                $isConcerning = $false
                $accountType = "Unknown"
                $risk = "Unknown"

                if ($rid -eq 500) {
                    $accountType = "Built-in Administrator"
                    if ($user.Disabled -eq $false) {
                        $isConcerning = $true
                        $risk = "Built-in Administrator account is enabled"
                    }
                } elseif ($rid -eq 501) {
                    $accountType = "Built-in Guest"
                    if ($user.Disabled -eq $false) {
                        $isConcerning = $true
                        $risk = "Built-in Guest account is enabled"
                    }
                } elseif ($rid -ge 1000) {
                    $accountType = "Custom Local Account"
                    $isConcerning = $true
                    $risk = "Custom local account on DC (DCs should not have local accounts)"
                }

                if ($isConcerning) {
                    $output += [PSCustomObject]@{
                        Label               = 'DC with Local Admin Account'
                        DCName              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                        DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                        DNSHostName         = $dnsHostName
                        OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                        LocalAccountName    = $user.Name
                        LocalAccountSID     = $user.SID
                        AccountType         = $accountType
                        Disabled            = $user.Disabled
                        Description         = $user.Description
                        LastLogin           = $user.LastLogin
                        Risk                = $risk
                        Severity            = if ($rid -ge 1000) { "HIGH" } else { "MEDIUM" }
                    }
                }
            }
        } catch {
            # Handle WMI access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check local accounts on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label               = 'DC Local Account Check Failed'
                DCName              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName   = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName         = $dnsHostName
                OperatingSystem     = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                LocalAccountName    = "Access Denied"
                LocalAccountSID     = "Access Denied"
                AccountType         = "Unknown"
                Disabled            = "Unknown"
                Description         = "WMI Access Failed"
                LastLogin           = "Unknown"
                Risk                = "Unable to verify local account status"
                Severity            = "UNKNOWN"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        $highRisk = ($output | Where-Object { $_.Severity -eq "HIGH" }).Count
        $mediumRisk = ($output | Where-Object { $_.Severity -eq "MEDIUM" }).Count

        Write-Host "`nSummary: Found $($output.Count) local account issues on Domain Controllers" -ForegroundColor Yellow
        Write-Host "  - High Risk (Custom accounts): $highRisk" -ForegroundColor Red
        Write-Host "  - Medium Risk (Built-in enabled): $mediumRisk" -ForegroundColor Yellow
        Write-Host "`nNote: DCs should not have local accounts accessible outside DSRM" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper local account configuration' -ForegroundColor Green
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

        Write-Host "`nSummary: Found $($output.Count) local account issues on Domain Controllers" -ForegroundColor Yellow
        Write-Host "  - High Risk (Custom accounts): $highRisk" -ForegroundColor Red
        Write-Host "  - Medium Risk (Built-in enabled): $mediumRisk" -ForegroundColor Yellow
        Write-Host "`nNote: DCs should not have local accounts accessible outside DSRM" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper local account configuration' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
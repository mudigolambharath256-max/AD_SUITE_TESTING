# Check: DCs with Unsigned LDAP Binds Allowed
# Category: Domain Controllers
# Severity: high
# ID: DC-018
# Requirements: None
# ============================================
# Check Event Log: Event ID 2887 in Directory Service log
# Registry: HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters\LDAPServerIntegrity

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + Event Log + Registry
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
            # Check LDAP Server Integrity registry setting
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)
            $regPath = "SYSTEM\CurrentControlSet\Services\NTDS\Parameters"
            $regKey = $reg.OpenSubKey($regPath)

            $ldapServerIntegrity = $null
            if ($regKey) {
                $ldapServerIntegrity = $regKey.GetValue("LDAPServerIntegrity")
                $regKey.Close()
            }
            $reg.Close()

            # Check for Event ID 2887 in Directory Service log (unsigned LDAP binds detected)
            $unsignedBindEvents = 0
            $lastUnsignedBind = $null

            try {
                # Look for Event ID 2887 in the last 7 days
                $startTime = (Get-Date).AddDays(-7)
                $events = Get-WinEvent -ComputerName $dnsHostName -FilterHashtable @{
                    LogName = 'Directory Service'
                    ID = 2887
                    StartTime = $startTime
                } -ErrorAction SilentlyContinue

                if ($events) {
                    $unsignedBindEvents = $events.Count
                    $lastUnsignedBind = $events[0].TimeCreated
                }
            } catch {
                # Event log access may fail, continue with registry check
            }

            # Determine if there are issues
            $hasIssues = $false
            $issues = @()

            # Check registry setting (should be 2 for required signing)
            if ($ldapServerIntegrity -lt 2) {
                $hasIssues = $true
                $ldapLevel = switch ($ldapServerIntegrity) {
                    0 { "None" }
                    1 { "Negotiate" }
                    2 { "Required" }
                    default { "Unknown/Not Set" }
                }
                $issues += "LDAP Server Integrity set to '$ldapLevel' (should be 'Required')"
            }

            # Check for unsigned bind events
            if ($unsignedBindEvents -gt 0) {
                $hasIssues = $true
                $issues += "Detected $unsignedBindEvents unsigned LDAP bind attempts in last 7 days"
            }

            if ($hasIssues) {
                $output += [PSCustomObject]@{
                    Label                   = 'DC with Unsigned LDAP Binds Allowed'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    LDAPServerIntegrity     = if ($ldapServerIntegrity -ne $null) { $ldapServerIntegrity } else { "Not Set" }
                    LDAPIntegrityLevel      = switch ($ldapServerIntegrity) {
                        0 { "None" }
                        1 { "Negotiate" }
                        2 { "Required" }
                        default { "Unknown/Not Set" }
                    }
                    UnsignedBindEvents      = $unsignedBindEvents
                    LastUnsignedBind        = if ($lastUnsignedBind) { $lastUnsignedBind } else { "None detected" }
                    Issues                  = ($issues -join '; ')
                    Severity                = "HIGH"
                    MITRE                   = "T1040"
                    Risk                    = "LDAP traffic interception, credential theft"
                }
            }
        } catch {
            # Handle remote access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check LDAP signing configuration on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC LDAP Signing Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                LDAPServerIntegrity     = "Access Denied"
                LDAPIntegrityLevel      = "Access Denied"
                UnsignedBindEvents      = "Access Denied"
                LastUnsignedBind        = "Access Denied"
                Issues                  = "Unable to verify LDAP signing configuration"
                Severity                = "UNKNOWN"
                MITRE                   = "T1040"
                Risk                    = "Unable to verify LDAP security"
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
                    checkid = 'DC-018'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-018_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Unsigned LDAP Binds Allowed
# Category: Domain Controllers
# Severity: high
# ID: DC-018
# Requirements: None
# ============================================
# Check Event Log: Event ID 2887 in Directory Service log
# Registry: HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters\LDAPServerIntegrity

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + Event Log + Registry
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
            # Check LDAP Server Integrity registry setting
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)
            $regPath = "SYSTEM\CurrentControlSet\Services\NTDS\Parameters"
            $regKey = $reg.OpenSubKey($regPath)

            $ldapServerIntegrity = $null
            if ($regKey) {
                $ldapServerIntegrity = $regKey.GetValue("LDAPServerIntegrity")
                $regKey.Close()
            }
            $reg.Close()

            # Check for Event ID 2887 in Directory Service log (unsigned LDAP binds detected)
            $unsignedBindEvents = 0
            $lastUnsignedBind = $null

            try {
                # Look for Event ID 2887 in the last 7 days
                $startTime = (Get-Date).AddDays(-7)
                $events = Get-WinEvent -ComputerName $dnsHostName -FilterHashtable @{
                    LogName = 'Directory Service'
                    ID = 2887
                    StartTime = $startTime
                } -ErrorAction SilentlyContinue

                if ($events) {
                    $unsignedBindEvents = $events.Count
                    $lastUnsignedBind = $events[0].TimeCreated
                }
            } catch {
                # Event log access may fail, continue with registry check
            }

            # Determine if there are issues
            $hasIssues = $false
            $issues = @()

            # Check registry setting (should be 2 for required signing)
            if ($ldapServerIntegrity -lt 2) {
                $hasIssues = $true
                $ldapLevel = switch ($ldapServerIntegrity) {
                    0 { "None" }
                    1 { "Negotiate" }
                    2 { "Required" }
                    default { "Unknown/Not Set" }
                }
                $issues += "LDAP Server Integrity set to '$ldapLevel' (should be 'Required')"
            }

            # Check for unsigned bind events
            if ($unsignedBindEvents -gt 0) {
                $hasIssues = $true
                $issues += "Detected $unsignedBindEvents unsigned LDAP bind attempts in last 7 days"
            }

            if ($hasIssues) {
                $output += [PSCustomObject]@{
                    Label                   = 'DC with Unsigned LDAP Binds Allowed'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    LDAPServerIntegrity     = if ($ldapServerIntegrity -ne $null) { $ldapServerIntegrity } else { "Not Set" }
                    LDAPIntegrityLevel      = switch ($ldapServerIntegrity) {
                        0 { "None" }
                        1 { "Negotiate" }
                        2 { "Required" }
                        default { "Unknown/Not Set" }
                    }
                    UnsignedBindEvents      = $unsignedBindEvents
                    LastUnsignedBind        = if ($lastUnsignedBind) { $lastUnsignedBind } else { "None detected" }
                    Issues                  = ($issues -join '; ')
                    Severity                = "HIGH"
                    MITRE                   = "T1040"
                    Risk                    = "LDAP traffic interception, credential theft"
                }
            }
        } catch {
            # Handle remote access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check LDAP signing configuration on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC LDAP Signing Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                LDAPServerIntegrity     = "Access Denied"
                LDAPIntegrityLevel      = "Access Denied"
                UnsignedBindEvents      = "Access Denied"
                LastUnsignedBind        = "Access Denied"
                Issues                  = "Unable to verify LDAP signing configuration"
                Severity                = "UNKNOWN"
                MITRE                   = "T1040"
                Risk                    = "Unable to verify LDAP security"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with unsigned LDAP bind issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers properly require LDAP signing' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with unsigned LDAP bind issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers properly require LDAP signing' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
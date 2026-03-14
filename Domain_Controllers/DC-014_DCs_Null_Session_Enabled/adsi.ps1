# Check: DCs Null Session Enabled
# Category: Domain Controllers
# Severity: high
# ID: DC-014
# Requirements: None
# ============================================
# Registry: HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters\RestrictNullSessAccess
# Registry: HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RestrictAnonymous

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

    $output = $results | ForEach-Object {
        $p = $_.Properties
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        # Skip if no DNS hostname
        if ($dnsHostName -eq 'N/A') {
            Write-Warning "Skipping DC with no DNS hostname: $($p['name'][0])"
            return
        }

        try {
            # Check null session registry keys via remote registry
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)

            # Check RestrictNullSessAccess
            $lanManPath = "SYSTEM\CurrentControlSet\Services\LanManServer\Parameters"
            $lanManKey = $reg.OpenSubKey($lanManPath)
            $restrictNullSess = $null
            if ($lanManKey) {
                $restrictNullSess = $lanManKey.GetValue("RestrictNullSessAccess")
                $lanManKey.Close()
            }

            # Check RestrictAnonymous
            $lsaPath = "SYSTEM\CurrentControlSet\Control\Lsa"
            $lsaKey = $reg.OpenSubKey($lsaPath)
            $restrictAnonymous = $null
            if ($lsaKey) {
                $restrictAnonymous = $lsaKey.GetValue("RestrictAnonymous")
                $lsaKey.Close()
            }

            $reg.Close()

            # Flag if null sessions are enabled (RestrictNullSessAccess=0 OR RestrictAnonymous < 2)
            $nullSessionEnabled = $false
            $issues = @()

            if ($restrictNullSess -eq 0) {
                $nullSessionEnabled = $true
                $issues += "RestrictNullSessAccess=0 (null sessions allowed)"
            }

            if ($restrictAnonymous -lt 2) {
                $nullSessionEnabled = $true
                $issues += "RestrictAnonymous=$restrictAnonymous (should be 2)"
            }

            if ($nullSessionEnabled) {
                [PSCustomObject]@{
                    Label                   = 'DC with Null Session Enabled'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    RestrictNullSessAccess  = if ($restrictNullSess -ne $null) { $restrictNullSess } else { "Key Not Found" }
                    RestrictAnonymous       = if ($restrictAnonymous -ne $null) { $restrictAnonymous } else { "Key Not Found" }
                    Issues                  = ($issues -join '; ')
                    Severity                = "HIGH"
                    Risk                    = "Anonymous enumeration, information disclosure"
                }
            }
        } catch {
            # Handle remote registry access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check null session settings on ${dnsHostName}: $_"
            [PSCustomObject]@{
                Label                   = 'DC with Null Session Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                RestrictNullSessAccess  = "Access Denied"
                RestrictAnonymous       = "Access Denied"
                Issues                  = "Unable to verify null session settings"
                Severity                = "UNKNOWN"
                Risk                    = "Unable to verify anonymous access restrictions"
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
                    checkid = 'DC-014'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-014_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs Null Session Enabled
# Category: Domain Controllers
# Severity: high
# ID: DC-014
# Requirements: None
# ============================================
# Registry: HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters\RestrictNullSessAccess
# Registry: HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RestrictAnonymous

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

    $output = $results | ForEach-Object {
        $p = $_.Properties
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        # Skip if no DNS hostname
        if ($dnsHostName -eq 'N/A') {
            Write-Warning "Skipping DC with no DNS hostname: $($p['name'][0])"
            return
        }

        try {
            # Check null session registry keys via remote registry
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)

            # Check RestrictNullSessAccess
            $lanManPath = "SYSTEM\CurrentControlSet\Services\LanManServer\Parameters"
            $lanManKey = $reg.OpenSubKey($lanManPath)
            $restrictNullSess = $null
            if ($lanManKey) {
                $restrictNullSess = $lanManKey.GetValue("RestrictNullSessAccess")
                $lanManKey.Close()
            }

            # Check RestrictAnonymous
            $lsaPath = "SYSTEM\CurrentControlSet\Control\Lsa"
            $lsaKey = $reg.OpenSubKey($lsaPath)
            $restrictAnonymous = $null
            if ($lsaKey) {
                $restrictAnonymous = $lsaKey.GetValue("RestrictAnonymous")
                $lsaKey.Close()
            }

            $reg.Close()

            # Flag if null sessions are enabled (RestrictNullSessAccess=0 OR RestrictAnonymous < 2)
            $nullSessionEnabled = $false
            $issues = @()

            if ($restrictNullSess -eq 0) {
                $nullSessionEnabled = $true
                $issues += "RestrictNullSessAccess=0 (null sessions allowed)"
            }

            if ($restrictAnonymous -lt 2) {
                $nullSessionEnabled = $true
                $issues += "RestrictAnonymous=$restrictAnonymous (should be 2)"
            }

            if ($nullSessionEnabled) {
                [PSCustomObject]@{
                    Label                   = 'DC with Null Session Enabled'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    RestrictNullSessAccess  = if ($restrictNullSess -ne $null) { $restrictNullSess } else { "Key Not Found" }
                    RestrictAnonymous       = if ($restrictAnonymous -ne $null) { $restrictAnonymous } else { "Key Not Found" }
                    Issues                  = ($issues -join '; ')
                    Severity                = "HIGH"
                    Risk                    = "Anonymous enumeration, information disclosure"
                }
            }
        } catch {
            # Handle remote registry access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check null session settings on ${dnsHostName}: $_"
            [PSCustomObject]@{
                Label                   = 'DC with Null Session Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                RestrictNullSessAccess  = "Access Denied"
                RestrictAnonymous       = "Access Denied"
                Issues                  = "Unable to verify null session settings"
                Severity                = "UNKNOWN"
                Risk                    = "Unable to verify anonymous access restrictions"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with null session issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have null sessions properly restricted' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with null session issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have null sessions properly restricted' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
# Check: DCs with Unsigned Drivers Allowed
# Category: Domain Controllers
# Severity: medium
# ID: DC-031
# Requirements: None
# ============================================
# Registry: HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\SigningPolicy

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

            # Check driver signing policy
            $sessionMgrPath = "SYSTEM\CurrentControlSet\Control\Session Manager"
            $sessionMgrKey = $reg.OpenSubKey($sessionMgrPath)
            $signingPolicy = $null
            if ($sessionMgrKey) {
                $signingPolicy = $sessionMgrKey.GetValue("SigningPolicy")
                $sessionMgrKey.Close()
            }

            # Check Windows NT driver signing policy
            $driverSigningPath = "SOFTWARE\Policies\Microsoft\Windows NT\Driver Signing"
            $driverSigningKey = $reg.OpenSubKey($driverSigningPath)
            $behaviorOnFailedVerify = $null
            if ($driverSigningKey) {
                $behaviorOnFailedVerify = $driverSigningKey.GetValue("BehaviorOnFailedVerify")
                $driverSigningKey.Close()
            }

            # Check Code Integrity policy
            $codeIntegrityPath = "SYSTEM\CurrentControlSet\Control\CI\Policy"
            $codeIntegrityKey = $reg.OpenSubKey($codeIntegrityPath)
            $verificationFlags = $null
            if ($codeIntegrityKey) {
                $verificationFlags = $codeIntegrityKey.GetValue("VerificationFlags")
                $codeIntegrityKey.Close()
            }

            $reg.Close()

            $issues = @()
            $severity = "MEDIUM"

            # Check signing policy (0 = full enforcement recommended)
            if ($signingPolicy -ne $null -and $signingPolicy -ne 0) {
                $issues += "SigningPolicy not set to full enforcement (value: $signingPolicy, should be 0)"
            }

            # Check behavior on failed verification (2 = block unsigned drivers)
            if ($behaviorOnFailedVerify -ne $null -and $behaviorOnFailedVerify -lt 2) {
                $behaviorText = switch ($behaviorOnFailedVerify) {
                    0 { "Ignore" }
                    1 { "Warn" }
                    2 { "Block" }
                    default { "Unknown" }
                }
                $issues += "BehaviorOnFailedVerify set to '$behaviorText' (should be 'Block')"
                $severity = "HIGH"
            }

            # Check if no driver signing policy is configured
            if ($signingPolicy -eq $null -and $behaviorOnFailedVerify -eq $null) {
                $issues += "No driver signing policy configured"
                $severity = "HIGH"
            }

            if ($issues.Count -gt 0) {
                $output += [PSCustomObject]@{
                    Label                       = 'DC with Unsigned Drivers Allowed'
                    Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName                 = $dnsHostName
                    OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    SigningPolicy               = if ($signingPolicy -ne $null) { $signingPolicy } else { "Not Set" }
                    BehaviorOnFailedVerify      = if ($behaviorOnFailedVerify -ne $null) { $behaviorOnFailedVerify } else { "Not Set" }
                    VerificationFlags           = if ($verificationFlags -ne $null) { $verificationFlags } else { "Not Set" }
                    Issues                      = ($issues -join '; ')
                    IssueCount                  = $issues.Count
                    Severity                    = $severity
                    Risk                        = "Unsigned driver installation, potential malware persistence"
                    Recommendation              = "Configure driver signing enforcement policies"
                }
            }
        } catch {
            Write-Warning "Unable to check driver signing policy on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                       = 'DC Driver Signing Check Failed'
                Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName                 = $dnsHostName
                OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                SigningPolicy               = "Access Denied"
                BehaviorOnFailedVerify      = "Access Denied"
                VerificationFlags           = "Access Denied"
                Issues                      = "Unable to verify driver signing configuration"
                IssueCount                  = "Unknown"
                Severity                    = "UNKNOWN"
                Risk                        = "Unable to verify driver signing enforcement"
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
                    checkid = 'DC-031'
                    severity = 'medium'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-031_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Unsigned Drivers Allowed
# Category: Domain Controllers
# Severity: medium
# ID: DC-031
# Requirements: None
# ============================================
# Registry: HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\SigningPolicy

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

            # Check driver signing policy
            $sessionMgrPath = "SYSTEM\CurrentControlSet\Control\Session Manager"
            $sessionMgrKey = $reg.OpenSubKey($sessionMgrPath)
            $signingPolicy = $null
            if ($sessionMgrKey) {
                $signingPolicy = $sessionMgrKey.GetValue("SigningPolicy")
                $sessionMgrKey.Close()
            }

            # Check Windows NT driver signing policy
            $driverSigningPath = "SOFTWARE\Policies\Microsoft\Windows NT\Driver Signing"
            $driverSigningKey = $reg.OpenSubKey($driverSigningPath)
            $behaviorOnFailedVerify = $null
            if ($driverSigningKey) {
                $behaviorOnFailedVerify = $driverSigningKey.GetValue("BehaviorOnFailedVerify")
                $driverSigningKey.Close()
            }

            # Check Code Integrity policy
            $codeIntegrityPath = "SYSTEM\CurrentControlSet\Control\CI\Policy"
            $codeIntegrityKey = $reg.OpenSubKey($codeIntegrityPath)
            $verificationFlags = $null
            if ($codeIntegrityKey) {
                $verificationFlags = $codeIntegrityKey.GetValue("VerificationFlags")
                $codeIntegrityKey.Close()
            }

            $reg.Close()

            $issues = @()
            $severity = "MEDIUM"

            # Check signing policy (0 = full enforcement recommended)
            if ($signingPolicy -ne $null -and $signingPolicy -ne 0) {
                $issues += "SigningPolicy not set to full enforcement (value: $signingPolicy, should be 0)"
            }

            # Check behavior on failed verification (2 = block unsigned drivers)
            if ($behaviorOnFailedVerify -ne $null -and $behaviorOnFailedVerify -lt 2) {
                $behaviorText = switch ($behaviorOnFailedVerify) {
                    0 { "Ignore" }
                    1 { "Warn" }
                    2 { "Block" }
                    default { "Unknown" }
                }
                $issues += "BehaviorOnFailedVerify set to '$behaviorText' (should be 'Block')"
                $severity = "HIGH"
            }

            # Check if no driver signing policy is configured
            if ($signingPolicy -eq $null -and $behaviorOnFailedVerify -eq $null) {
                $issues += "No driver signing policy configured"
                $severity = "HIGH"
            }

            if ($issues.Count -gt 0) {
                $output += [PSCustomObject]@{
                    Label                       = 'DC with Unsigned Drivers Allowed'
                    Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName                 = $dnsHostName
                    OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    SigningPolicy               = if ($signingPolicy -ne $null) { $signingPolicy } else { "Not Set" }
                    BehaviorOnFailedVerify      = if ($behaviorOnFailedVerify -ne $null) { $behaviorOnFailedVerify } else { "Not Set" }
                    VerificationFlags           = if ($verificationFlags -ne $null) { $verificationFlags } else { "Not Set" }
                    Issues                      = ($issues -join '; ')
                    IssueCount                  = $issues.Count
                    Severity                    = $severity
                    Risk                        = "Unsigned driver installation, potential malware persistence"
                    Recommendation              = "Configure driver signing enforcement policies"
                }
            }
        } catch {
            Write-Warning "Unable to check driver signing policy on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                       = 'DC Driver Signing Check Failed'
                Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName                 = $dnsHostName
                OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                SigningPolicy               = "Access Denied"
                BehaviorOnFailedVerify      = "Access Denied"
                VerificationFlags           = "Access Denied"
                Issues                      = "Unable to verify driver signing configuration"
                IssueCount                  = "Unknown"
                Severity                    = "UNKNOWN"
                Risk                        = "Unable to verify driver signing enforcement"
                Recommendation              = "Manual verification required"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with driver signing issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper driver signing enforcement' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with driver signing issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper driver signing enforcement' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
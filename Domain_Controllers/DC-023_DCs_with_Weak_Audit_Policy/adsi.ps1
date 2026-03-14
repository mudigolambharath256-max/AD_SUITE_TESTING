# Check: DCs with Weak Audit Policy
# Category: Domain Controllers
# Severity: high
# ID: DC-023
# Requirements: None
# ============================================
# Check advanced audit policy per DC via auditpol /get /category:*

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + Remote Command
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

    # Required audit categories for DCs
    $requiredCategories = @{
        "Account Logon" = @("Success", "Failure")
        "Account Management" = @("Success", "Failure")
        "DS Access" = @("Success", "Failure")
        "Logon/Logoff" = @("Success", "Failure")
        "Object Access" = @("Success", "Failure")
        "Policy Change" = @("Success", "Failure")
        "Privilege Use" = @("Success", "Failure")
        "System" = @("Success", "Failure")
    }

    $output = @()

    foreach ($result in $results) {
        $p = $result.Properties
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        if ($dnsHostName -eq 'N/A') {
            Write-Warning "Skipping DC with no DNS hostname: $($p['name'][0])"
            continue
        }

        try {
            # Execute auditpol remotely
            $auditOutput = Invoke-Command -ComputerName $dnsHostName -ScriptBlock {
                auditpol /get /category:* 2>$null
            } -ErrorAction Stop

            $weakCategories = @()
            $missingCategories = @()

            foreach ($category in $requiredCategories.Keys) {
                $categoryFound = $false
                $hasSuccess = $false
                $hasFailure = $false

                foreach ($line in $auditOutput) {
                    if ($line -match $category) {
                        $categoryFound = $true
                        if ($line -match "Success") { $hasSuccess = $true }
                        if ($line -match "Failure") { $hasFailure = $true }
                    }
                }

                if (-not $categoryFound) {
                    $missingCategories += $category
                } elseif (-not $hasSuccess -or -not $hasFailure) {
                    $weakCategories += "$category (missing Success and/or Failure)"
                }
            }

            if ($weakCategories.Count -gt 0 -or $missingCategories.Count -gt 0) {
                $issues = @()
                if ($weakCategories.Count -gt 0) { $issues += $weakCategories }
                if ($missingCategories.Count -gt 0) { $issues += ($missingCategories | ForEach-Object { "$_ (not configured)" }) }

                $output += [PSCustomObject]@{
                    Label                   = 'DC with Weak Audit Policy'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    WeakCategories          = ($weakCategories -join '; ')
                    MissingCategories       = ($missingCategories -join '; ')
                    IssueCount              = $issues.Count
                    Issues                  = ($issues -join '; ')
                    Severity                = if ($missingCategories.Count -gt 3) { "CRITICAL" } elseif ($issues.Count -gt 5) { "HIGH" } else { "MEDIUM" }
                    Risk                    = "Insufficient audit logging for security monitoring"
                    Recommendation          = "Configure all required audit categories for Success and Failure"
                }
            }
        } catch {
            Write-Warning "Unable to check audit policy on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC Audit Policy Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                WeakCategories          = "Access Denied"
                MissingCategories       = "Access Denied"
                IssueCount              = "Unknown"
                Issues                  = "Unable to verify audit policy configuration"
                Severity                = "UNKNOWN"
                Risk                    = "Unable to verify audit configuration"
                Recommendation          = "Manual audit policy verification required"
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
                    checkid = 'DC-023'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-023_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Weak Audit Policy
# Category: Domain Controllers
# Severity: high
# ID: DC-023
# Requirements: None
# ============================================
# Check advanced audit policy per DC via auditpol /get /category:*

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + Remote Command
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

    # Required audit categories for DCs
    $requiredCategories = @{
        "Account Logon" = @("Success", "Failure")
        "Account Management" = @("Success", "Failure")
        "DS Access" = @("Success", "Failure")
        "Logon/Logoff" = @("Success", "Failure")
        "Object Access" = @("Success", "Failure")
        "Policy Change" = @("Success", "Failure")
        "Privilege Use" = @("Success", "Failure")
        "System" = @("Success", "Failure")
    }

    $output = @()

    foreach ($result in $results) {
        $p = $result.Properties
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        if ($dnsHostName -eq 'N/A') {
            Write-Warning "Skipping DC with no DNS hostname: $($p['name'][0])"
            continue
        }

        try {
            # Execute auditpol remotely
            $auditOutput = Invoke-Command -ComputerName $dnsHostName -ScriptBlock {
                auditpol /get /category:* 2>$null
            } -ErrorAction Stop

            $weakCategories = @()
            $missingCategories = @()

            foreach ($category in $requiredCategories.Keys) {
                $categoryFound = $false
                $hasSuccess = $false
                $hasFailure = $false

                foreach ($line in $auditOutput) {
                    if ($line -match $category) {
                        $categoryFound = $true
                        if ($line -match "Success") { $hasSuccess = $true }
                        if ($line -match "Failure") { $hasFailure = $true }
                    }
                }

                if (-not $categoryFound) {
                    $missingCategories += $category
                } elseif (-not $hasSuccess -or -not $hasFailure) {
                    $weakCategories += "$category (missing Success and/or Failure)"
                }
            }

            if ($weakCategories.Count -gt 0 -or $missingCategories.Count -gt 0) {
                $issues = @()
                if ($weakCategories.Count -gt 0) { $issues += $weakCategories }
                if ($missingCategories.Count -gt 0) { $issues += ($missingCategories | ForEach-Object { "$_ (not configured)" }) }

                $output += [PSCustomObject]@{
                    Label                   = 'DC with Weak Audit Policy'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    WeakCategories          = ($weakCategories -join '; ')
                    MissingCategories       = ($missingCategories -join '; ')
                    IssueCount              = $issues.Count
                    Issues                  = ($issues -join '; ')
                    Severity                = if ($missingCategories.Count -gt 3) { "CRITICAL" } elseif ($issues.Count -gt 5) { "HIGH" } else { "MEDIUM" }
                    Risk                    = "Insufficient audit logging for security monitoring"
                    Recommendation          = "Configure all required audit categories for Success and Failure"
                }
            }
        } catch {
            Write-Warning "Unable to check audit policy on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC Audit Policy Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                WeakCategories          = "Access Denied"
                MissingCategories       = "Access Denied"
                IssueCount              = "Unknown"
                Issues                  = "Unable to verify audit policy configuration"
                Severity                = "UNKNOWN"
                Risk                    = "Unable to verify audit configuration"
                Recommendation          = "Manual audit policy verification required"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with audit policy issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper audit policy configuration' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with audit policy issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper audit policy configuration' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
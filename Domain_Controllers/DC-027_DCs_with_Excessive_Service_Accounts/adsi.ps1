# Check: DCs with Excessive Service Accounts
# Category: Domain Controllers
# Severity: medium
# ID: DC-027
# Requirements: None
# ============================================
# LDAP Filter: (&(objectClass=user)(objectCategory=person)(servicePrincipalName=*))

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + WMI
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()

    # First get all DCs
    $dcSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $dcSearcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $dcSearcher.Filter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $dcSearcher.PageSize = 1000
    $dcSearcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'dNSHostName', 'objectSid') | ForEach-Object { [void]$dcSearcher.PropertiesToLoad.Add($_) }

    $dcResults = $dcSearcher.FindAll()
    Write-Host "Found $($dcResults.Count) Domain Controllers" -ForegroundColor Cyan

    # Get service accounts with SPNs
    $svcSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $svcSearcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $svcSearcher.Filter = '(&(objectClass=user)(objectCategory=person)(servicePrincipalName=*))'
    $svcSearcher.PageSize = 1000
    $svcSearcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'samAccountName', 'servicePrincipalName', 'adminCount', 'memberOf', 'userAccountControl', 'objectSid') | ForEach-Object { [void]$svcSearcher.PropertiesToLoad.Add($_) }

    $svcResults = $svcSearcher.FindAll()
    Write-Host "Found $($svcResults.Count) service accounts with SPNs" -ForegroundColor Cyan

    $output = @()

    # Check service accounts for excessive privileges
    foreach ($svcAccount in $svcResults) {
        $p = $svcAccount.Properties
        $accountName = if ($p['samaccountname'] -and $p['samaccountname'].Count -gt 0) { $p['samaccountname'][0] } else { 'N/A' }

        # Skip standard accounts
        if ($accountName -match '^(krbtgt|KRBTGT)$') {
            continue
        }

        $issues = @()
        $severity = "MEDIUM"

        # Check if service account has adminCount=1 (privileged)
        $adminCount = if ($p['admincount'] -and $p['admincount'].Count -gt 0) { $p['admincount'][0] } else { 0 }
        if ($adminCount -eq 1) {
            $issues += "Service account has adminCount=1 (privileged)"
            $severity = "HIGH"
        }

        # Check group memberships for privileged groups
        if ($p['memberof'] -and $p['memberof'].Count -gt 0) {
            $privilegedGroups = @()
            foreach ($group in $p['memberof']) {
                if ($group -match 'CN=(Domain Admins|Enterprise Admins|Schema Admins|Administrators|Backup Operators|Server Operators|Print Operators)') {
                    $privilegedGroups += ($group -replace '^CN=([^,]+),.*', '$1')
                }
            }

            if ($privilegedGroups.Count -gt 0) {
                $issues += "Member of privileged groups: $($privilegedGroups -join ', ')"
                $severity = "HIGH"
            }
        }

        # Check SPNs for DC-related services
        if ($p['serviceprincipalname'] -and $p['serviceprincipalname'].Count -gt 0) {
            $dcSpns = @()
            foreach ($spn in $p['serviceprincipalname']) {
                if ($spn -match '^(HOST|GC|ldap|DNS|Kerberos)/' -and $spn -notmatch '^HOST/[^.]+$') {
                    $dcSpns += $spn
                }
            }

            if ($dcSpns.Count -gt 0) {
                $issues += "Has DC-related SPNs: $($dcSpns -join ', ')"
                $severity = "HIGH"
            }
        }

        if ($issues.Count -gt 0) {
            $output += [PSCustomObject]@{
                Label                   = 'DC with Excessive Service Account'
                ServiceAccountName      = $accountName
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                AdminCount              = $adminCount
                ServicePrincipalNames   = if ($p['serviceprincipalname'] -and $p['serviceprincipalname'].Count -gt 0) { ($p['serviceprincipalname'] -join '; ') } else { 'None' }
                Issues                  = ($issues -join '; ')
                IssueCount              = $issues.Count
                Severity                = $severity
                Risk                    = "Excessive service account privileges on Domain Controllers"
                Recommendation          = "Review service account permissions and group memberships"
            }
        }
    }

    # Also check services running on DCs with non-standard accounts
    foreach ($dc in $dcResults) {
        $p = $dc.Properties
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        if ($dnsHostName -eq 'N/A') {
            continue
        }

        try {
            $services = Get-WmiObject -Class Win32_Service -ComputerName $dnsHostName -ErrorAction Stop

            foreach ($service in $services) {
                # Flag services running as domain accounts (not SYSTEM/LocalService/NetworkService)
                if ($service.StartName -and $service.StartName -notmatch '^(LocalSystem|NT AUTHORITY\\|\.\\)' -and $service.StartName -match '\\') {
                    $output += [PSCustomObject]@{
                        Label                   = 'DC Service with Domain Account'
                        ServiceAccountName      = $service.StartName
                        DCName                  = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                        DNSHostName             = $dnsHostName
                        ServiceName             = $service.Name
                        ServiceDisplayName      = $service.DisplayName
                        ServiceState            = $service.State
                        Issues                  = "Service running with domain account on DC"
                        IssueCount              = 1
                        Severity                = "MEDIUM"
                        Risk                    = "Domain account compromise affects DC services"
                        Recommendation          = "Use managed service accounts (gMSA) or built-in accounts"
                    }
                }
            }
        } catch {
            Write-Warning "Unable to check services on ${dnsHostName}: $_"
        }
    }

    $svcResults.Dispose()
    $svcSearcher.Dispose()
    $dcResults.Dispose()
    $dcSearcher.Dispose()

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
                    checkid = 'DC-027'
                    severity = 'medium'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-027_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Excessive Service Accounts
# Category: Domain Controllers
# Severity: medium
# ID: DC-027
# Requirements: None
# ============================================
# LDAP Filter: (&(objectClass=user)(objectCategory=person)(servicePrincipalName=*))

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + WMI
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()

    # First get all DCs
    $dcSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $dcSearcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $dcSearcher.Filter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $dcSearcher.PageSize = 1000
    $dcSearcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'dNSHostName', 'objectSid') | ForEach-Object { [void]$dcSearcher.PropertiesToLoad.Add($_) }

    $dcResults = $dcSearcher.FindAll()
    Write-Host "Found $($dcResults.Count) Domain Controllers" -ForegroundColor Cyan

    # Get service accounts with SPNs
    $svcSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $svcSearcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $svcSearcher.Filter = '(&(objectClass=user)(objectCategory=person)(servicePrincipalName=*))'
    $svcSearcher.PageSize = 1000
    $svcSearcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'samAccountName', 'servicePrincipalName', 'adminCount', 'memberOf', 'userAccountControl', 'objectSid') | ForEach-Object { [void]$svcSearcher.PropertiesToLoad.Add($_) }

    $svcResults = $svcSearcher.FindAll()
    Write-Host "Found $($svcResults.Count) service accounts with SPNs" -ForegroundColor Cyan

    $output = @()

    # Check service accounts for excessive privileges
    foreach ($svcAccount in $svcResults) {
        $p = $svcAccount.Properties
        $accountName = if ($p['samaccountname'] -and $p['samaccountname'].Count -gt 0) { $p['samaccountname'][0] } else { 'N/A' }

        # Skip standard accounts
        if ($accountName -match '^(krbtgt|KRBTGT)$') {
            continue
        }

        $issues = @()
        $severity = "MEDIUM"

        # Check if service account has adminCount=1 (privileged)
        $adminCount = if ($p['admincount'] -and $p['admincount'].Count -gt 0) { $p['admincount'][0] } else { 0 }
        if ($adminCount -eq 1) {
            $issues += "Service account has adminCount=1 (privileged)"
            $severity = "HIGH"
        }

        # Check group memberships for privileged groups
        if ($p['memberof'] -and $p['memberof'].Count -gt 0) {
            $privilegedGroups = @()
            foreach ($group in $p['memberof']) {
                if ($group -match 'CN=(Domain Admins|Enterprise Admins|Schema Admins|Administrators|Backup Operators|Server Operators|Print Operators)') {
                    $privilegedGroups += ($group -replace '^CN=([^,]+),.*', '$1')
                }
            }

            if ($privilegedGroups.Count -gt 0) {
                $issues += "Member of privileged groups: $($privilegedGroups -join ', ')"
                $severity = "HIGH"
            }
        }

        # Check SPNs for DC-related services
        if ($p['serviceprincipalname'] -and $p['serviceprincipalname'].Count -gt 0) {
            $dcSpns = @()
            foreach ($spn in $p['serviceprincipalname']) {
                if ($spn -match '^(HOST|GC|ldap|DNS|Kerberos)/' -and $spn -notmatch '^HOST/[^.]+$') {
                    $dcSpns += $spn
                }
            }

            if ($dcSpns.Count -gt 0) {
                $issues += "Has DC-related SPNs: $($dcSpns -join ', ')"
                $severity = "HIGH"
            }
        }

        if ($issues.Count -gt 0) {
            $output += [PSCustomObject]@{
                Label                   = 'DC with Excessive Service Account'
                ServiceAccountName      = $accountName
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                AdminCount              = $adminCount
                ServicePrincipalNames   = if ($p['serviceprincipalname'] -and $p['serviceprincipalname'].Count -gt 0) { ($p['serviceprincipalname'] -join '; ') } else { 'None' }
                Issues                  = ($issues -join '; ')
                IssueCount              = $issues.Count
                Severity                = $severity
                Risk                    = "Excessive service account privileges on Domain Controllers"
                Recommendation          = "Review service account permissions and group memberships"
            }
        }
    }

    # Also check services running on DCs with non-standard accounts
    foreach ($dc in $dcResults) {
        $p = $dc.Properties
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        if ($dnsHostName -eq 'N/A') {
            continue
        }

        try {
            $services = Get-WmiObject -Class Win32_Service -ComputerName $dnsHostName -ErrorAction Stop

            foreach ($service in $services) {
                # Flag services running as domain accounts (not SYSTEM/LocalService/NetworkService)
                if ($service.StartName -and $service.StartName -notmatch '^(LocalSystem|NT AUTHORITY\\|\.\\)' -and $service.StartName -match '\\') {
                    $output += [PSCustomObject]@{
                        Label                   = 'DC Service with Domain Account'
                        ServiceAccountName      = $service.StartName
                        DCName                  = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                        DNSHostName             = $dnsHostName
                        ServiceName             = $service.Name
                        ServiceDisplayName      = $service.DisplayName
                        ServiceState            = $service.State
                        Issues                  = "Service running with domain account on DC"
                        IssueCount              = 1
                        Severity                = "MEDIUM"
                        Risk                    = "Domain account compromise affects DC services"
                        Recommendation          = "Use managed service accounts (gMSA) or built-in accounts"
                    }
                }
            }
        } catch {
            Write-Warning "Unable to check services on ${dnsHostName}: $_"
        }
    }

    $svcResults.Dispose()
    $svcSearcher.Dispose()
    $dcResults.Dispose()
    $dcSearcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) service account issues on Domain Controllers" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - Domain Controller service accounts appear properly configured' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) service account issues on Domain Controllers" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - Domain Controller service accounts appear properly configured' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
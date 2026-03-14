# Check: DCs Replication Failures
# Category: Domain Controllers
# Severity: critical
# ID: DC-013
# Requirements: None
# ============================================
# Query: nTDSDSA objects in Configuration NC for replication metadata

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
    $root = [ADSI]'LDAP://RootDSE'
    $configNC = $root.configurationNamingContext.ToString()
    $domainNC = $root.defaultNamingContext.ToString()

    # First get all DCs
    $dcSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $dcSearcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $dcSearcher.Filter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $dcSearcher.PageSize = 1000
    $dcSearcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'dNSHostName', 'objectSid', 'samAccountName') | ForEach-Object { [void]$dcSearcher.PropertiesToLoad.Add($_) }

    $dcResults = $dcSearcher.FindAll()
    Write-Host "Found $($dcResults.Count) Domain Controllers" -ForegroundColor Cyan

    $output = @()

    foreach ($dc in $dcResults) {
        $dcName = if ($dc.Properties['name'] -and $dc.Properties['name'].Count -gt 0) { $dc.Properties['name'][0] } else { 'N/A' }
        $dcDNS = if ($dc.Properties['dnshostname'] -and $dc.Properties['dnshostname'].Count -gt 0) { $dc.Properties['dnshostname'][0] } else { 'N/A' }

        # Query NTDS Settings for this DC
        $ntdsSearcher = New-Object System.DirectoryServices.DirectorySearcher
        $ntdsSearcher.SearchRoot = [ADSI]"LDAP://$configNC"
        $ntdsSearcher.Filter = "(&(objectClass=nTDSDSA)(|(cn=NTDS Settings)(name=NTDS Settings)))"
        $ntdsSearcher.PageSize = 1000
        $ntdsSearcher.PropertiesToLoad.Clear()
        @('distinguishedName', 'repsFrom', 'repsTo', 'whenChanged', 'objectSid', 'samAccountName') | ForEach-Object { [void]$ntdsSearcher.PropertiesToLoad.Add($_) }

        $ntdsResults = $ntdsSearcher.FindAll()

        foreach ($ntds in $ntdsResults) {
            $ntdsDN = if ($ntds.Properties['distinguishedname'] -and $ntds.Properties['distinguishedname'].Count -gt 0) { $ntds.Properties['distinguishedname'][0] } else { 'N/A' }

            # Check if this NTDS object belongs to current DC
            if ($ntdsDN -like "*$dcName*") {
                $repsFrom = if ($ntds.Properties['repsfrom'] -and $ntds.Properties['repsfrom'].Count -gt 0) { $ntds.Properties['repsfrom'].Count } else { 0 }
                $repsTo = if ($ntds.Properties['repsto'] -and $ntds.Properties['repsto'].Count -gt 0) { $ntds.Properties['repsto'].Count } else { 0 }
                $lastChanged = if ($ntds.Properties['whenchanged'] -and $ntds.Properties['whenchanged'].Count -gt 0) { $ntds.Properties['whenchanged'][0] } else { 'N/A' }

                # Calculate hours since last replication
                $hoursSinceReplication = 'N/A'
                if ($lastChanged -ne 'N/A') {
                    try {
                        $lastChangedDate = [DateTime]::Parse($lastChanged)
                        $hoursSinceReplication = [math]::Round(((Get-Date) - $lastChangedDate).TotalHours, 2)
                    } catch {
                        $hoursSinceReplication = 'Parse Error'
                    }
                }

                # Flag if replication issues detected
                $hasIssue = $false
                $issueReason = @()

                if ($repsFrom -eq 0) {
                    $hasIssue = $true
                    $issueReason += "No inbound replication partners"
                }

                if ($hoursSinceReplication -ne 'N/A' -and $hoursSinceReplication -ne 'Parse Error' -and $hoursSinceReplication -gt 4) {
                    $hasIssue = $true
                    $issueReason += "Last replication > 4 hours ago ($hoursSinceReplication hours)"
                }

                if ($hasIssue) {
                    $output += [PSCustomObject]@{
                        Label                   = 'DC Replication Failure'
                        Name                    = $dcName
                        DistinguishedName       = if ($dc.Properties['distinguishedname'] -and $dc.Properties['distinguishedname'].Count -gt 0) { $dc.Properties['distinguishedname'][0] } else { 'N/A' }
                        DNSHostName             = $dcDNS
                        NTDSSettingsDN          = $ntdsDN
                        InboundPartners         = $repsFrom
                        OutboundPartners        = $repsTo
                        LastReplicationChange   = $lastChanged
                        HoursSinceReplication   = $hoursSinceReplication
                        IssueReason             = ($issueReason -join '; ')
                    }
                }
            }
        }

        $ntdsSearcher.Dispose()
        $ntdsResults.Dispose()
    }

    $dcResults.Dispose()
    $dcSearcher.Dispose()

    if ($output) {
        Write-Host "Found $($output.Count) DCs with replication issues" -ForegroundColor Yellow
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
                    checkid = 'DC-013'
                    severity = 'critical'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-013_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs Replication Failures
# Category: Domain Controllers
# Severity: critical
# ID: DC-013
# Requirements: None
# ============================================
# Query: nTDSDSA objects in Configuration NC for replication metadata

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
    $root = [ADSI]'LDAP://RootDSE'
    $configNC = $root.configurationNamingContext.ToString()
    $domainNC = $root.defaultNamingContext.ToString()

    # First get all DCs
    $dcSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $dcSearcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $dcSearcher.Filter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $dcSearcher.PageSize = 1000
    $dcSearcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'dNSHostName', 'objectSid', 'samAccountName') | ForEach-Object { [void]$dcSearcher.PropertiesToLoad.Add($_) }

    $dcResults = $dcSearcher.FindAll()
    Write-Host "Found $($dcResults.Count) Domain Controllers" -ForegroundColor Cyan

    $output = @()

    foreach ($dc in $dcResults) {
        $dcName = if ($dc.Properties['name'] -and $dc.Properties['name'].Count -gt 0) { $dc.Properties['name'][0] } else { 'N/A' }
        $dcDNS = if ($dc.Properties['dnshostname'] -and $dc.Properties['dnshostname'].Count -gt 0) { $dc.Properties['dnshostname'][0] } else { 'N/A' }

        # Query NTDS Settings for this DC
        $ntdsSearcher = New-Object System.DirectoryServices.DirectorySearcher
        $ntdsSearcher.SearchRoot = [ADSI]"LDAP://$configNC"
        $ntdsSearcher.Filter = "(&(objectClass=nTDSDSA)(|(cn=NTDS Settings)(name=NTDS Settings)))"
        $ntdsSearcher.PageSize = 1000
        $ntdsSearcher.PropertiesToLoad.Clear()
        @('distinguishedName', 'repsFrom', 'repsTo', 'whenChanged', 'objectSid', 'samAccountName') | ForEach-Object { [void]$ntdsSearcher.PropertiesToLoad.Add($_) }

        $ntdsResults = $ntdsSearcher.FindAll()

        foreach ($ntds in $ntdsResults) {
            $ntdsDN = if ($ntds.Properties['distinguishedname'] -and $ntds.Properties['distinguishedname'].Count -gt 0) { $ntds.Properties['distinguishedname'][0] } else { 'N/A' }

            # Check if this NTDS object belongs to current DC
            if ($ntdsDN -like "*$dcName*") {
                $repsFrom = if ($ntds.Properties['repsfrom'] -and $ntds.Properties['repsfrom'].Count -gt 0) { $ntds.Properties['repsfrom'].Count } else { 0 }
                $repsTo = if ($ntds.Properties['repsto'] -and $ntds.Properties['repsto'].Count -gt 0) { $ntds.Properties['repsto'].Count } else { 0 }
                $lastChanged = if ($ntds.Properties['whenchanged'] -and $ntds.Properties['whenchanged'].Count -gt 0) { $ntds.Properties['whenchanged'][0] } else { 'N/A' }

                # Calculate hours since last replication
                $hoursSinceReplication = 'N/A'
                if ($lastChanged -ne 'N/A') {
                    try {
                        $lastChangedDate = [DateTime]::Parse($lastChanged)
                        $hoursSinceReplication = [math]::Round(((Get-Date) - $lastChangedDate).TotalHours, 2)
                    } catch {
                        $hoursSinceReplication = 'Parse Error'
                    }
                }

                # Flag if replication issues detected
                $hasIssue = $false
                $issueReason = @()

                if ($repsFrom -eq 0) {
                    $hasIssue = $true
                    $issueReason += "No inbound replication partners"
                }

                if ($hoursSinceReplication -ne 'N/A' -and $hoursSinceReplication -ne 'Parse Error' -and $hoursSinceReplication -gt 4) {
                    $hasIssue = $true
                    $issueReason += "Last replication > 4 hours ago ($hoursSinceReplication hours)"
                }

                if ($hasIssue) {
                    $output += [PSCustomObject]@{
                        Label                   = 'DC Replication Failure'
                        Name                    = $dcName
                        DistinguishedName       = if ($dc.Properties['distinguishedname'] -and $dc.Properties['distinguishedname'].Count -gt 0) { $dc.Properties['distinguishedname'][0] } else { 'N/A' }
                        DNSHostName             = $dcDNS
                        NTDSSettingsDN          = $ntdsDN
                        InboundPartners         = $repsFrom
                        OutboundPartners        = $repsTo
                        LastReplicationChange   = $lastChanged
                        HoursSinceReplication   = $hoursSinceReplication
                        IssueReason             = ($issueReason -join '; ')
                    }
                }
            }
        }

        $ntdsSearcher.Dispose()
        $ntdsResults.Dispose()
    }

    $dcResults.Dispose()
    $dcSearcher.Dispose()

    if ($output) {
        Write-Host "Found $($output.Count) DCs with replication issues" -ForegroundColor Yellow
        $output | Format-Table -AutoSize
    } else {
        Write-Host 'No replication failures detected' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory replication query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
    } else {
        Write-Host 'No replication failures detected' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory replication query failed: $_"
    exit 1
}
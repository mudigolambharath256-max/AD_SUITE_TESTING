# Check: Domain Controllers Inventory
# Category: Domain Controllers
# Severity: info
# ID: DC-001
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP
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
    (@('name', 'distinguishedName', 'samAccountName', 'dNSHostName', 'operatingSystem', 'operatingSystemVersion', 'whenCreated', 'lastLogonTimestamp', 'userAccountControl', 'objectSid', 'msDS-SupportedEncryptionTypes', 'primaryGroupID', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) Domain Controllers" -ForegroundColor Cyan

    $output = $results | ForEach-Object {
        $p = $_.Properties
        [PSCustomObject]@{
            Label                       = 'Domain Controllers Inventory'
            Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
            DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
            SamAccountName              = if ($p['samaccountname'] -and $p['samaccountname'].Count -gt 0) { $p['samaccountname'][0] } else { 'N/A' }
            DNSHostName                 = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }
            OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
            OperatingSystemVersion      = if ($p['operatingsystemversion'] -and $p['operatingsystemversion'].Count -gt 0) { $p['operatingsystemversion'][0] } else { 'N/A' }
            WhenCreated                 = if ($p['whencreated'] -and $p['whencreated'].Count -gt 0) { $p['whencreated'][0] } else { 'N/A' }
            LastLogonTimestamp          = if ($p['lastlogontimestamp'] -and $p['lastlogontimestamp'].Count -gt 0) {
                try {
                    [DateTime]::FromFileTime($p['lastlogontimestamp'][0])
                } catch {
                    $p['lastlogontimestamp'][0]
                }
            } else { 'N/A' }
            UserAccountControl          = if ($p['useraccountcontrol'] -and $p['useraccountcontrol'].Count -gt 0) { $p['useraccountcontrol'][0] } else { 'N/A' }
            ObjectSid                   = if ($p['objectsid'] -and $p['objectsid'].Count -gt 0) {
                try {
                    (New-Object System.Security.Principal.SecurityIdentifier($p['objectsid'][0], 0)).Value
                } catch {
                    'Parse Error'
                }
            } else { 'N/A' }
            SupportedEncryptionTypes    = if ($p['msds-supportedencryptiontypes'] -and $p['msds-supportedencryptiontypes'].Count -gt 0) { $p['msds-supportedencryptiontypes'][0] } else { 'N/A' }
            PrimaryGroupID              = if ($p['primarygroupid'] -and $p['primarygroupid'].Count -gt 0) { $p['primarygroupid'][0] } else { 'N/A' }
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
                    checkid = 'DC-001'
                    severity = 'info'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-001_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: Domain Controllers Inventory
# Category: Domain Controllers
# Severity: info
# ID: DC-001
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP
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
    (@('name', 'distinguishedName', 'samAccountName', 'dNSHostName', 'operatingSystem', 'operatingSystemVersion', 'whenCreated', 'lastLogonTimestamp', 'userAccountControl', 'objectSid', 'msDS-SupportedEncryptionTypes', 'primaryGroupID', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) Domain Controllers" -ForegroundColor Cyan

    $output = $results | ForEach-Object {
        $p = $_.Properties
        [PSCustomObject]@{
            Label                       = 'Domain Controllers Inventory'
            Name                        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
            DistinguishedName           = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
            SamAccountName              = if ($p['samaccountname'] -and $p['samaccountname'].Count -gt 0) { $p['samaccountname'][0] } else { 'N/A' }
            DNSHostName                 = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }
            OperatingSystem             = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
            OperatingSystemVersion      = if ($p['operatingsystemversion'] -and $p['operatingsystemversion'].Count -gt 0) { $p['operatingsystemversion'][0] } else { 'N/A' }
            WhenCreated                 = if ($p['whencreated'] -and $p['whencreated'].Count -gt 0) { $p['whencreated'][0] } else { 'N/A' }
            LastLogonTimestamp          = if ($p['lastlogontimestamp'] -and $p['lastlogontimestamp'].Count -gt 0) {
                try {
                    [DateTime]::FromFileTime($p['lastlogontimestamp'][0])
                } catch {
                    $p['lastlogontimestamp'][0]
                }
            } else { 'N/A' }
            UserAccountControl          = if ($p['useraccountcontrol'] -and $p['useraccountcontrol'].Count -gt 0) { $p['useraccountcontrol'][0] } else { 'N/A' }
            ObjectSid                   = if ($p['objectsid'] -and $p['objectsid'].Count -gt 0) {
                try {
                    (New-Object System.Security.Principal.SecurityIdentifier($p['objectsid'][0], 0)).Value
                } catch {
                    'Parse Error'
                }
            } else { 'N/A' }
            SupportedEncryptionTypes    = if ($p['msds-supportedencryptiontypes'] -and $p['msds-supportedencryptiontypes'].Count -gt 0) { $p['msds-supportedencryptiontypes'][0] } else { 'N/A' }
            PrimaryGroupID              = if ($p['primarygroupid'] -and $p['primarygroupid'].Count -gt 0) { $p['primarygroupid'][0] } else { 'N/A' }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers in inventory" -ForegroundColor Green
    } else {
        Write-Host 'No Domain Controllers found' -ForegroundColor Gray
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
}
"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers in inventory" -ForegroundColor Green
    } else {
        Write-Host 'No Domain Controllers found' -ForegroundColor Gray
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
}

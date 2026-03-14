# Check: FRS SYSVOL (Deprecated)
# Category: Domain Controllers
# Severity: high
# ID: DC-005
# Requirements: None
# ============================================
# # Objects live under CN=System in the domain NC - explicit SearchRoot required.

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $root     = [ADSI]'LDAP://RootDSE'
        $domainNC = $root.defaultNamingContext.ToString()
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.SearchRoot = [ADSI]"LDAP://CN=System,$domainNC"
    $searcher.Filter     = '(&(objectClass=nTFRSReplicaSet)(cn=Domain System Volume*))'
    $searcher.PageSize   = 1000
    $searcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'cn', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan

    $output = $results | ForEach-Object {
      $p = $_.Properties
        [PSCustomObject]@{
        Label             = 'FRS SYSVOL (Deprecated)'
        Name                      = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
        DistinguishedName         = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
        CN                        = if ($p['cn'] -and $p['cn'].Count -gt 0) { $p['cn'][0] } else { 'N/A' }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) { $output | Format-Table -AutoSize }


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
                    checkid = 'DC-005'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-005_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: FRS SYSVOL (Deprecated)
# Category: Domain Controllers
# Severity: high
# ID: DC-005
# Requirements: None
# ============================================
# # Objects live under CN=System in the domain NC - explicit SearchRoot required.

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $root     = [ADSI]'LDAP://RootDSE'
        $domainNC = $root.defaultNamingContext.ToString()
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.SearchRoot = [ADSI]"LDAP://CN=System,$domainNC"
    $searcher.Filter     = '(&(objectClass=nTFRSReplicaSet)(cn=Domain System Volume*))'
    $searcher.PageSize   = 1000
    $searcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'cn', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) objects" -ForegroundColor Cyan

    $output = $results | ForEach-Object {
      $p = $_.Properties
        [PSCustomObject]@{
        Label             = 'FRS SYSVOL (Deprecated)'
        Name                      = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
        DistinguishedName         = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
        CN                        = if ($p['cn'] -and $p['cn'].Count -gt 0) { $p['cn'][0] } else { 'N/A' }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) { $output | Format-Table -AutoSize }
    else { Write-Host 'No findings' -ForegroundColor Gray }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
    else { Write-Host 'No findings' -ForegroundColor Gray }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}

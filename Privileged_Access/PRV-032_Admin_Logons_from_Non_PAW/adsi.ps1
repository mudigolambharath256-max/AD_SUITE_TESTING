# ============================================================================
# PRV-032: Admin Logons from Non PAW
# ============================================================================
# Category: Privileged_Access
# Method: ADSI
# Severity: HIGH
# MITRE: T1078.002
# ============================================================================

# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
    $root = [ADSI]'LDAP://RootDSE'
$domainNC = $root.defaultNamingContext.ToString()
} catch {
    Write-Error \"Cannot connect to Active Directory: $_\"
    exit 1
}
$searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.SearchRoot = [ADSI]"LDAP://$domainNC"
$searcher.Filter = '(&(objectCategory=person)(objectClass=user)(adminCount=1))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'whenCreated', 'whenChanged', 'adminCount', 'samAccountName', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_)
}

try {
    $results = $searcher.FindAll()
} catch {
    Write-Error \"LDAP query failed: $_\"
    $searcher.Dispose()
    exit 1
}
Write-Host "Found $($results.Count) objects for check: Admin Logons from Non PAW" -ForegroundColor Cyan

$results | ForEach-Object {
    $props = $_.Properties
    [PSCustomObject]@{
        CheckID = 'PRV-032'
        CheckName = 'Admin Logons from Non PAW'
        Name = if ($props['name'].Count -gt 0) { $props['name'][0]
        AdminCount = if ($props['admincount'].Count -gt 0) { $props['admincount'][0]
        SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0]
    SamAccountName = if ($props['samaccountname'] -and $props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A' } } else { 'N/A'
        SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } }
        SamAccountName = if ($props['samaccountname'].Count -gt 0) { $props['samaccountname'][0] } else { 'N/A' } } else { 'N/A' }
        DistinguishedName = if ($props['distinguishedname'].Count -gt 0) { $props['distinguishedname'][0] } else { 'N/A' }
        RiskScore = 7
        Severity = 'HIGH'
        MITRE = 'T1078.002'
    }
}

$results.Dispose()
$searcher.Dispose()


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
                    checkid = 'PRV-032'
                    severity = 'HIGH'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "PRV-032_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: $_"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================

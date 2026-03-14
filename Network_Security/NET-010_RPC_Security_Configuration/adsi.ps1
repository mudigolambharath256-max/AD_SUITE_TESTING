# ============================================================================
# NET-010: RPC Security Configuration
# ============================================================================
# Version: 3.0.0
# Category: Network_Security
# Method: ADSI
# Severity: HIGH
# MITRE: T1021
# ============================================================================

# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
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
$searcher.Filter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'whenCreated', 'whenChanged', 'userAccountControl', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_)
}

Write-Host "[NET-010] RPC Security Configuration" -ForegroundColor Cyan
Write-Host "Severity: HIGH | Risk: 7/10" -ForegroundColor Gray

try {
    $results = $searcher.FindAll()
} catch {
    Write-Error \"LDAP query failed: $_\"
    $searcher.Dispose()
    exit 1
}
Write-Host "Found $($results.Count) objects" -ForegroundColor $(if ($results.Count -gt 0) { 'Yellow' } else { 'Green' })

$results | ForEach-Object {
    $props = $_.Properties
    [PSCustomObject]@{
        CheckID = 'NET-010'
        CheckName = 'RPC Security Configuration'
        Name = if ($props['name'].Count -gt 0) { $props['name'][0]
        UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
    UserAccountControl = if ($props['useraccountcontrol'] -and $props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0] } else { 'N/A' } } else { 'N/A' } } else { 'N/A' }
        DistinguishedName = if ($props['distinguishedname'].Count -gt 0) { $props['distinguishedname'][0] } else { 'N/A' }
        RiskScore = 7
        Severity = 'HIGH'
        MITRE = 'T1021'
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
                    checkid = 'NET-010'
                    severity = 'HIGH'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "NET-010_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: $_"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================

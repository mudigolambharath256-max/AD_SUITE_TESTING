# ============================================================================
# PKI-021: Enrollment Service Permissions
# ============================================================================
# Category: PKI_Services
# Method: ADSI (Active Directory Service Interfaces)
# Description: Uses DirectorySearcher for LDAP queries without requiring
#              the ActiveDirectory PowerShell module
# ============================================================================
# USAGE:
#   .\adsi.ps1
#
# OUTPUT:
#   Returns objects matching the security check criteria
# ============================================================================

# Initialize LDAP connection to domain
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

# Create DirectorySearcher object for LDAP queries
$searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.SearchRoot = [ADSI]"LDAP://$domainNC"

# Set LDAP filter for the security check
$searcher.Filter = '(objectClass=pKIEnrollmentService)'

# Configure paging for large result sets
$searcher.PageSize = 1000

# Clear default properties and add specific ones
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'objectClass', 'whenCreated', 'whenChanged', 'objectSid', 'samAccountName') | ForEach-Object {
    [void]$searcher.PropertiesToLoad.Add($_)
}

# Execute search and process results
try {
    $results = $searcher.FindAll()
} catch {
    Write-Error \"LDAP query failed: $_\"
    $searcher.Dispose()
    exit 1
}

Write-Host "Found $($results.Count) objects for check: Enrollment Service Permissions" -ForegroundColor Cyan

$results | ForEach-Object {
    $props = $_.Properties

    # Create custom object with relevant properties
    [PSCustomObject]@{
        CheckID           = 'PKI-021'
        CheckName         = 'Enrollment Service Permissions'
        Name              = if ($props['name'].Count -gt 0) { $props['name'][0] } else { 'N/A' }
        DistinguishedName = if ($props['distinguishedname'].Count -gt 0) { $props['distinguishedname'][0] } else { 'N/A' }
        ObjectClass       = if ($props['objectclass'].Count -gt 0) { $props['objectclass'][0] } else { 'N/A' }
        WhenCreated       = if ($props['whencreated'].Count -gt 0) { $props['whencreated'][0] } else { 'N/A' }
        WhenChanged       = if ($props['whenchanged'].Count -gt 0) { $props['whenchanged'][0] } else { 'N/A' }
    }
}

# Cleanup
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
                    checkid = 'PKI-021'
                    severity = 'MEDIUM'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "PKI-021_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: $_"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================

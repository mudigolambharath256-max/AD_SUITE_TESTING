# ============================================================
# CHECK: AD-002_Domain_Functional_Level
# CATEGORY: Domain_Configuration
# DESCRIPTION: Checks domain functional level for security features
# LDAP FILTER: (objectClass=domainDNS)
# SEARCH BASE: Default NC (Base scope on domain root)
# OBJECT CLASS: domainDNS
# ATTRIBUTES: msDS-Behavior-Version, distinguishedName, name
# RISK: MEDIUM
# MITRE ATT&CK: T1484 (Domain Policy Modification)
# ============================================================

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    # Query domain root object for functional level
    $searcher = [ADSISearcher]'(objectClass=domainDNS)'
    $searcher.SearchScope = 'Base'
    $searcher.PageSize = 1000
    $searcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'msDS-Behavior-Version', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) domain objects" -ForegroundColor Cyan

    $output = $results | ForEach-Object {
      $p = $_.Properties
      $functionalLevel = if ($p['msds-behavior-version'] -and $p['msds-behavior-version'].Count -gt 0) { $p['msds-behavior-version'][0] } else { 0 }

      # Map functional level to OS version
      $levelMap = @{
          0 = "Windows 2000"
          1 = "Windows Server 2003 Interim"
          2 = "Windows Server 2003"
          3 = "Windows Server 2008"
          4 = "Windows Server 2008 R2"
          5 = "Windows Server 2012"
          6 = "Windows Server 2012 R2"
          7 = "Windows Server 2016"
          10 = "Windows Server 2019/2022"
      }

      $levelName = if ($levelMap.ContainsKey($functionalLevel)) { $levelMap[$functionalLevel] } else { "Unknown ($functionalLevel)" }
      $severity = if ($functionalLevel -lt 7) { "HIGH" } else { "MEDIUM" }

      [PSCustomObject]@{
        CheckID = 'AD-002'
        CheckName = 'Domain Functional Level'
        Domain = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
        ObjectDN = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
        ObjectName = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
        FindingDetail = "Domain functional level: $functionalLevel ($levelName)"
        Severity = $severity
        Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
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
                    checkid = 'AD-002'
                    severity = 'MEDIUM'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "AD-002_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # ============================================================
# CHECK: AD-002_Domain_Functional_Level
# CATEGORY: Domain_Configuration
# DESCRIPTION: Checks domain functional level for security features
# LDAP FILTER: (objectClass=domainDNS)
# SEARCH BASE: Default NC (Base scope on domain root)
# OBJECT CLASS: domainDNS
# ATTRIBUTES: msDS-Behavior-Version, distinguishedName, name
# RISK: MEDIUM
# MITRE ATT&CK: T1484 (Domain Policy Modification)
# ============================================================

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    # Query domain root object for functional level
    $searcher = [ADSISearcher]'(objectClass=domainDNS)'
    $searcher.SearchScope = 'Base'
    $searcher.PageSize = 1000
    $searcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'msDS-Behavior-Version', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) domain objects" -ForegroundColor Cyan

    $output = $results | ForEach-Object {
      $p = $_.Properties
      $functionalLevel = if ($p['msds-behavior-version'] -and $p['msds-behavior-version'].Count -gt 0) { $p['msds-behavior-version'][0] } else { 0 }

      # Map functional level to OS version
      $levelMap = @{
          0 = "Windows 2000"
          1 = "Windows Server 2003 Interim"
          2 = "Windows Server 2003"
          3 = "Windows Server 2008"
          4 = "Windows Server 2008 R2"
          5 = "Windows Server 2012"
          6 = "Windows Server 2012 R2"
          7 = "Windows Server 2016"
          10 = "Windows Server 2019/2022"
      }

      $levelName = if ($levelMap.ContainsKey($functionalLevel)) { $levelMap[$functionalLevel] } else { "Unknown ($functionalLevel)" }
      $severity = if ($functionalLevel -lt 7) { "HIGH" } else { "MEDIUM" }

      [PSCustomObject]@{
        CheckID = 'AD-002'
        CheckName = 'Domain Functional Level'
        Domain = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
        ObjectDN = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
        ObjectName = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
        FindingDetail = "Domain functional level: $functionalLevel ($levelName)"
        Severity = $severity
        Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
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

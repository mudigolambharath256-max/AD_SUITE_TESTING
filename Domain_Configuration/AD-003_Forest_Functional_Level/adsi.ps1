# ============================================================
# CHECK: AD-003_Forest_Functional_Level
# CATEGORY: Domain_Configuration
# DESCRIPTION: Checks forest functional level for security features
# LDAP FILTER: (objectClass=crossRefContainer)
# SEARCH BASE: CN=Partitions,CN=Configuration,<ForestDN>
# OBJECT CLASS: crossRefContainer
# ATTRIBUTES: msDS-Behavior-Version, distinguishedName
# RISK: MEDIUM
# MITRE ATT&CK: T1484 (Domain Policy Modification)
# ============================================================

# ADSI DirectorySearcher Implementation
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP Configuration NC
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
    # Get forest root domain DN
    $rootDSE = [ADSI]"LDAP://RootDSE"
    $configNC = $rootDSE.configurationNamingContext[0]

    # Query Partitions container for forest functional level
    $searcher = [ADSISearcher]"LDAP://CN=Partitions,$configNC"
    $searcher.Filter = '(objectClass=crossRefContainer)'
    $searcher.SearchScope = 'Base'
    $searcher.PropertiesToLoad.Clear()
    @('msDS-Behavior-Version', 'distinguishedName', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $result = $searcher.FindOne()

    if ($result) {
        $p = $result.Properties
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

        $output = [PSCustomObject]@{
            CheckID = 'AD-003'
            CheckName = 'Forest Functional Level'
            Domain = $rootDSE.defaultNamingContext[0] -replace '^DC=|,DC=', '' -replace ',DC=', '.'
            ObjectDN = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
            ObjectName = 'Forest Root'
            FindingDetail = "Forest functional level: $functionalLevel ($levelName)"
            Severity = $severity
            Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
        }

        Write-Host "Found forest functional level: $functionalLevel ($levelName)" -ForegroundColor Cyan
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
                    checkid = 'AD-003'
                    severity = 'MEDIUM'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "AD-003_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # ============================================================
# CHECK: AD-003_Forest_Functional_Level
# CATEGORY: Domain_Configuration
# DESCRIPTION: Checks forest functional level for security features
# LDAP FILTER: (objectClass=crossRefContainer)
# SEARCH BASE: CN=Partitions,CN=Configuration,<ForestDN>
# OBJECT CLASS: crossRefContainer
# ATTRIBUTES: msDS-Behavior-Version, distinguishedName
# RISK: MEDIUM
# MITRE ATT&CK: T1484 (Domain Policy Modification)
# ============================================================

# ADSI DirectorySearcher Implementation
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP Configuration NC
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
    # Get forest root domain DN
    $rootDSE = [ADSI]"LDAP://RootDSE"
    $configNC = $rootDSE.configurationNamingContext[0]

    # Query Partitions container for forest functional level
    $searcher = [ADSISearcher]"LDAP://CN=Partitions,$configNC"
    $searcher.Filter = '(objectClass=crossRefContainer)'
    $searcher.SearchScope = 'Base'
    $searcher.PropertiesToLoad.Clear()
    @('msDS-Behavior-Version', 'distinguishedName', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $result = $searcher.FindOne()

    if ($result) {
        $p = $result.Properties
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

        $output = [PSCustomObject]@{
            CheckID = 'AD-003'
            CheckName = 'Forest Functional Level'
            Domain = $rootDSE.defaultNamingContext[0] -replace '^DC=|,DC=', '' -replace ',DC=', '.'
            ObjectDN = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
            ObjectName = 'Forest Root'
            FindingDetail = "Forest functional level: $functionalLevel ($levelName)"
            Severity = $severity
            Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
        }

        Write-Host "Found forest functional level: $functionalLevel ($levelName)" -ForegroundColor Cyan
        $output | Format-Table -AutoSize
    } else {
        Write-Host 'No forest functional level found' -ForegroundColor Gray
    }

    $searcher.Dispose()

} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
    } else {
        Write-Host 'No forest functional level found' -ForegroundColor Gray
    }

    $searcher.Dispose()

} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
# Check: FSMO Role Holders
# Category: Domain Controllers
# Severity: info
# ID: DC-007
# Requirements: None
# ============================================
# LDAP search (ADSI / DirectorySearcher)

# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $root     = [ADSI]"LDAP://RootDSE"
    $domainNC = $root.defaultNamingContext.ToString()

    # PDC Emulator + RIDManagerReference — from domain root object
    $searchRoot = [ADSI]("LDAP://" + $domainNC)
    $searcher = New-Object System.DirectoryServices.DirectorySearcher($searchRoot)
    $searcher.Filter = '(objectClass=domainDNS)'
    $searcher.PageSize = 1000
    $searcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'fSMORoleOwner', 'rIDManagerReference', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $domainResult = $searcher.FindOne()

    # Infrastructure Master — from CN=Infrastructure
    $infraEntry = [ADSI]("LDAP://CN=Infrastructure," + $domainNC)
    $infraOwner = if ($infraEntry -and $infraEntry.Properties['fSMORoleOwner'].Count -gt 0) {
        $infraEntry.Properties['fSMORoleOwner'][0]
    } else { '(not set)' }

    if ($domainResult) {
        $p = $domainResult.Properties
        [PSCustomObject]@{
            Label                = 'FSMO Role Holders'
            Name                 = if ($p['name'].Count -gt 0) { $p['name'][0] } else { $null }
            DistinguishedName    = if ($p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { $null }
            FSMORoleOwner        = if ($p['fsmoroleowner'].Count -gt 0) { $p['fsmoroleowner'][0] } else { $null }
            RIDManagerReference  = if ($p['ridmanagerreference'].Count -gt 0) { $p['ridmanagerreference'][0] } else { $null }
            InfrastructureMaster = $infraOwner
        }
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}


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
                    checkid = 'DC-007'
                    severity = 'info'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-007_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: $_"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================

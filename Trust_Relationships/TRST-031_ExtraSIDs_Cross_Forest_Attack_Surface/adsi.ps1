# ============================================================
# CHECK: TRST-031_ExtraSIDs_Cross_Forest_Attack_Surface
# CATEGORY: Trust_Relationships
# DESCRIPTION: Detects forest trusts vulnerable to ExtraSIDs attacks
# LDAP FILTER: (&(objectClass=trustedDomain)(trustType=2))
# SEARCH BASE: CN=System,<DomainDN>
# OBJECT CLASS: trustedDomain
# ATTRIBUTES: trustPartner, trustDirection, trustType, trustAttributes, securityIdentifier
# RISK: CRITICAL
# MITRE ATT&CK: T1134.005 (Access Token Manipulation: SID-History Injection)
# ============================================================

# ADSI DirectorySearcher Implementation
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP System Container
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
    # Get current domain DN
    $rootDSE = [ADSI]"LDAP://RootDSE"
    $domainDN = $rootDSE.defaultNamingContext[0]

    # Query forest trusts (trustType=2)
    $searcher = [ADSISearcher]"LDAP://CN=System,$domainDN"
    $searcher.Filter = '(&(objectClass=trustedDomain)(trustType=2))'
    $searcher.PageSize = 1000
    $searcher.PropertiesToLoad.Clear()
    @('trustPartner', 'trustDirection', 'trustType', 'trustAttributes', 'securityIdentifier', 'distinguishedName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $trustResults = $searcher.FindAll()
    Write-Host "Found $($trustResults.Count) forest trusts to analyze" -ForegroundColor Cyan

    $findings = @()

    foreach ($trustResult in $trustResults) {
        $trustProps = $trustResult.Properties
        $trustPartner = if ($trustProps['trustpartner'] -and $trustProps['trustpartner'].Count -gt 0) { $trustProps['trustpartner'][0] } else { 'Unknown' }
        $trustDirection = if ($trustProps['trustdirection'] -and $trustProps['trustdirection'].Count -gt 0) { $trustProps['trustdirection'][0] } else { 0 }
        $trustAttributes = if ($trustProps['trustattributes'] -and $trustProps['trustattributes'].Count -gt 0) { $trustProps['trustattributes'][0] } else { 0 }
        $trustDN = if ($trustProps['distinguishedname'] -and $trustProps['distinguishedname'].Count -gt 0) { $trustProps['distinguishedname'][0] } else { 'N/A' }

        # Analyze trust attributes for ExtraSIDs attack surface
        $vulnerabilities = @()

        # Check if SID filtering is disabled (TREAT_AS_EXTERNAL bit NOT set)
        # Bit 0x04 (4) = TREAT_AS_EXTERNAL (quarantined = SID filter ON)
        if (($trustAttributes -band 4) -eq 0) {
            $vulnerabilities += "SID filtering disabled - ExtraSIDs attack possible"
        }

        # Check for other risky trust attributes
        if (($trustAttributes -band 8) -ne 0) {
            $vulnerabilities += "Uses RC4 encryption (bit 0x08) - downgrade risk"
        }

        if (($trustAttributes -band 32) -eq 0) {
            $vulnerabilities += "No selective authentication (bit 0x20) - broader access"
        }

        # Check trust direction for inbound component (ExtraSIDs come FROM trusted forest)
        $directionRisk = ""
        switch ($trustDirection) {
            1 { $directionRisk = "Inbound trust - can receive ExtraSIDs from $trustPartner" }
            2 { $directionRisk = "Outbound trust - no direct ExtraSIDs risk" }
            3 { $directionRisk = "Bidirectional trust - can receive ExtraSIDs from $trustPartner" }
            default { $directionRisk = "Unknown direction ($trustDirection)" }
        }

        # Only flag trusts that can receive ExtraSIDs (inbound or bidirectional)
        if ($trustDirection -eq 1 -or $trustDirection -eq 3) {
            if ($vulnerabilities.Count -gt 0) {
                $severity = if (($trustAttributes -band 4) -eq 0) { "CRITICAL" } else { "HIGH" }

                $findings += [PSCustomObject]@{
                    CheckID = 'TRST-031'
                    CheckName = 'ExtraSIDs Cross Forest Attack Surface'
                    Domain = $domainDN -replace '^DC=|,DC=', '' -replace ',DC=', '.'
                    ObjectDN = $trustDN
                    ObjectName = $trustPartner
                    FindingDetail = "Forest trust vulnerable to ExtraSIDs: $($vulnerabilities -join '; ') | $directionRisk | trustAttributes=0x$($trustAttributes.ToString('X'))"
                    Severity = $severity
                    Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
    }

    # Also check for accounts with cross-forest SID History
    Write-Host "Checking for accounts with cross-forest SID History..." -ForegroundColor Cyan

    $sidHistorySearcher = [ADSISearcher]"LDAP://$domainDN"
    $sidHistorySearcher.Filter = '(&(objectClass=user)(sIDHistory=*))'
    $sidHistorySearcher.PageSize = 1000
    $sidHistorySearcher.PropertiesToLoad.Clear()
    @('sAMAccountName', 'sIDHistory', 'distinguishedName', 'objectSid') | ForEach-Object { [void]$sidHistorySearcher.PropertiesToLoad.Add($_) }

    $sidHistoryResults = $sidHistorySearcher.FindAll()

    # Get current domain SID prefix for comparison
    $currentDomainSid = (New-Object System.Security.Principal.SecurityIdentifier($rootDSE.objectSid[0], 0)).AccountDomainSid.Value

    foreach ($sidResult in $sidHistoryResults) {
        $sidProps = $sidResult.Properties
        $accountName = if ($sidProps['samaccountname'] -and $sidProps['samaccountname'].Count -gt 0) { $sidProps['samaccountname'][0] } else { 'Unknown' }
        $accountDN = if ($sidProps['distinguishedname'] -and $sidProps['distinguishedname'].Count -gt 0) { $sidProps['distinguishedname'][0] } else { 'N/A' }

        if ($sidProps['sidhistory'] -and $sidProps['sidhistory'].Count -gt 0) {
            foreach ($historySidBytes in $sidProps['sidhistory']) {
                try {
                    $historySid = New-Object System.Security.Principal.SecurityIdentifier($historySidBytes, 0)
                    $historySidString = $historySid.Value

                    # Check if SID History belongs to a different forest (different domain SID prefix)
                    if (-not $historySidString.StartsWith($currentDomainSid)) {
                        $findings += [PSCustomObject]@{
                            CheckID = 'TRST-031'
                            CheckName = 'ExtraSIDs Cross Forest Attack Surface'
                            Domain = $domainDN -replace '^DC=|,DC=', '' -replace ',DC=', '.'
                            ObjectDN = $accountDN
                            ObjectName = $accountName
                            FindingDetail = "Account has cross-forest SID History: $historySidString (potential ExtraSIDs vector)"
                            Severity = "HIGH"
                            Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                        }
                    }
                } catch {
                    Write-Warning "Could not parse SID History for $accountName"
                }
            }
        }
    }

    $trustResults.Dispose()
    $sidHistoryResults.Dispose()
    $searcher.Dispose()
    $sidHistorySearcher.Dispose()

    if ($findings) {
        Write-Host "Found $($findings.Count) ExtraSIDs attack surface issues" -ForegroundColor Red
        $findings | Format-Table -AutoSize
    } else {
        Write-Host 'No ExtraSIDs attack surface detected' -ForegroundColor Green
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
                    checkid = 'TRST-031'
                    severity = 'MEDIUM'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "TRST-031_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: $_"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================

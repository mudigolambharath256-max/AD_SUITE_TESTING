# Check: RODC Credential Caching Policy
# Category: Domain Controllers
# Severity: high
# ID: DC-040
# Requirements: None
# ============================================
# LDAP Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=67108864))

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
    $searcher.Filter     = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=67108864))'
    $searcher.PageSize   = 1000
    $searcher.PropertiesToLoad.Clear()
    (@('name', 'distinguishedName', 'dNSHostName', 'msDS-NeverRevealGroup', 'msDS-RevealOnDemandGroup', 'msDS-RevealedList', 'msDS-KrbTgtLinkBl', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) Read-Only Domain Controllers (RODCs)" -ForegroundColor Cyan

    if ($results.Count -eq 0) {
        Write-Host 'No RODCs found in this domain' -ForegroundColor Green
        return
    }

    # Get privileged groups that should NEVER be cached on RODCs
    $privilegedGroups = @(
        "CN=Domain Admins,CN=Users,$domainNC",
        "CN=Enterprise Admins,CN=Users,$domainNC",
        "CN=Schema Admins,CN=Users,$domainNC",
        "CN=Administrators,CN=Builtin,$domainNC",
        "CN=Group Policy Creator Owners,CN=Users,$domainNC",
        "CN=Domain Controllers,CN=Users,$domainNC",
        "CN=Denied RODC Password Replication Group,CN=Users,$domainNC"
    )

    $output = @()

    foreach ($result in $results) {
        $p = $result.Properties
        $rodcName = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }

        $issues = @()
        $severity = "HIGH"

        # Check msDS-NeverRevealGroup (accounts that should NEVER be cached)
        $neverRevealGroups = @()
        if ($p['msds-neverrevealgroup'] -and $p['msds-neverrevealgroup'].Count -gt 0) {
            $neverRevealGroups = $p['msds-neverrevealgroup']
        }

        # Check if all privileged groups are in NeverRevealGroup
        $missingPrivilegedGroups = @()
        foreach ($privGroup in $privilegedGroups) {
            if ($neverRevealGroups -notcontains $privGroup) {
                $groupName = ($privGroup -replace '^CN=([^,]+),.*', '$1')
                $missingPrivilegedGroups += $groupName
            }
        }

        if ($missingPrivilegedGroups.Count -gt 0) {
            $issues += "Privileged groups not in NeverRevealGroup: $($missingPrivilegedGroups -join ', ')"
            $severity = "CRITICAL"
        }

        # Check msDS-RevealedList (accounts whose credentials ARE currently cached)
        $revealedAccounts = @()
        if ($p['msds-revealedlist'] -and $p['msds-revealedlist'].Count -gt 0) {
            $revealedAccounts = $p['msds-revealedlist']
        }

        if ($revealedAccounts.Count -gt 0) {
            # Check if any revealed accounts are privileged (have adminCount=1)
            $privilegedRevealed = @()
            foreach ($accountDN in $revealedAccounts) {
                try {
                    $accountSearcher = New-Object System.DirectoryServices.DirectorySearcher
                    $accountSearcher.SearchRoot = [ADSI]"LDAP://$domainNC"
                    $accountSearcher.Filter = "(distinguishedName=$accountDN)"
                    $accountSearcher.PropertiesToLoad.Clear()
                    @('samAccountName', 'adminCount', 'memberOf', 'objectSid') | ForEach-Object { [void]$accountSearcher.PropertiesToLoad.Add($_) }

                    $accountResult = $accountSearcher.FindOne()
                    if ($accountResult) {
                        $accountProps = $accountResult.Properties
                        $adminCount = if ($accountProps['admincount'] -and $accountProps['admincount'].Count -gt 0) { $accountProps['admincount'][0] } else { 0 }
                        $samAccountName = if ($accountProps['samaccountname'] -and $accountProps['samaccountname'].Count -gt 0) { $accountProps['samaccountname'][0] } else { 'Unknown' }

                        if ($adminCount -eq 1) {
                            $privilegedRevealed += $samAccountName
                        }
                    }
                    $accountSearcher.Dispose()
                } catch {
                    # Account lookup failed, continue
                }
            }

            if ($privilegedRevealed.Count -gt 0) {
                $issues += "Privileged accounts cached on RODC: $($privilegedRevealed -join ', ')"
                $severity = "CRITICAL"
            }

            $issues += "Total accounts with cached credentials: $($revealedAccounts.Count)"
        }

        # Check msDS-RevealOnDemandGroup (accounts that CAN be cached)
        $revealOnDemandGroups = @()
        if ($p['msds-revealondemandgroup'] -and $p['msds-revealondemandgroup'].Count -gt 0) {
            $revealOnDemandGroups = $p['msds-revealondemandgroup']

            # Check if any privileged groups are in RevealOnDemandGroup (should not be)
            $privilegedInRevealOnDemand = @()
            foreach ($privGroup in $privilegedGroups) {
                if ($revealOnDemandGroups -contains $privGroup) {
                    $groupName = ($privGroup -replace '^CN=([^,]+),.*', '$1')
                    $privilegedInRevealOnDemand += $groupName
                }
            }

            if ($privilegedInRevealOnDemand.Count -gt 0) {
                $issues += "Privileged groups in RevealOnDemandGroup: $($privilegedInRevealOnDemand -join ', ')"
                $severity = "CRITICAL"
            }
        }

        if ($issues.Count -gt 0 -or $neverRevealGroups.Count -eq 0) {
            if ($neverRevealGroups.Count -eq 0) {
                $issues += "No NeverRevealGroup configured (all accounts may be cacheable)"
                $severity = "CRITICAL"
            }

            $output += [PSCustomObject]@{
                Label                   = 'RODC with Insecure Credential Caching Policy'
                RODCName                = $rodcName
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }
                NeverRevealGroupCount   = $neverRevealGroups.Count
                RevealOnDemandCount     = $revealOnDemandGroups.Count
                RevealedAccountsCount   = $revealedAccounts.Count
                Issues                  = ($issues -join '; ')
                IssueCount              = $issues.Count
                Severity                = $severity
                MITRE                   = "T1552.004"
                Risk                    = "RODC compromise yields cached privileged credentials"
                Recommendation          = "Configure NeverRevealGroup to exclude all privileged accounts"
            }
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
                    checkid = 'DC-040'
                    severity = 'high'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-040_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: RODC Credential Caching Policy
# Category: Domain Controllers
# Severity: high
# ID: DC-040
# Requirements: None
# ============================================
# LDAP Filter: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=67108864))

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
    $searcher.Filter     = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=67108864))'
    $searcher.PageSize   = 1000
    $searcher.PropertiesToLoad.Clear()
    (@('name', 'distinguishedName', 'dNSHostName', 'msDS-NeverRevealGroup', 'msDS-RevealOnDemandGroup', 'msDS-RevealedList', 'msDS-KrbTgtLinkBl', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) Read-Only Domain Controllers (RODCs)" -ForegroundColor Cyan

    if ($results.Count -eq 0) {
        Write-Host 'No RODCs found in this domain' -ForegroundColor Green
        return
    }

    # Get privileged groups that should NEVER be cached on RODCs
    $privilegedGroups = @(
        "CN=Domain Admins,CN=Users,$domainNC",
        "CN=Enterprise Admins,CN=Users,$domainNC",
        "CN=Schema Admins,CN=Users,$domainNC",
        "CN=Administrators,CN=Builtin,$domainNC",
        "CN=Group Policy Creator Owners,CN=Users,$domainNC",
        "CN=Domain Controllers,CN=Users,$domainNC",
        "CN=Denied RODC Password Replication Group,CN=Users,$domainNC"
    )

    $output = @()

    foreach ($result in $results) {
        $p = $result.Properties
        $rodcName = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }

        $issues = @()
        $severity = "HIGH"

        # Check msDS-NeverRevealGroup (accounts that should NEVER be cached)
        $neverRevealGroups = @()
        if ($p['msds-neverrevealgroup'] -and $p['msds-neverrevealgroup'].Count -gt 0) {
            $neverRevealGroups = $p['msds-neverrevealgroup']
        }

        # Check if all privileged groups are in NeverRevealGroup
        $missingPrivilegedGroups = @()
        foreach ($privGroup in $privilegedGroups) {
            if ($neverRevealGroups -notcontains $privGroup) {
                $groupName = ($privGroup -replace '^CN=([^,]+),.*', '$1')
                $missingPrivilegedGroups += $groupName
            }
        }

        if ($missingPrivilegedGroups.Count -gt 0) {
            $issues += "Privileged groups not in NeverRevealGroup: $($missingPrivilegedGroups -join ', ')"
            $severity = "CRITICAL"
        }

        # Check msDS-RevealedList (accounts whose credentials ARE currently cached)
        $revealedAccounts = @()
        if ($p['msds-revealedlist'] -and $p['msds-revealedlist'].Count -gt 0) {
            $revealedAccounts = $p['msds-revealedlist']
        }

        if ($revealedAccounts.Count -gt 0) {
            # Check if any revealed accounts are privileged (have adminCount=1)
            $privilegedRevealed = @()
            foreach ($accountDN in $revealedAccounts) {
                try {
                    $accountSearcher = New-Object System.DirectoryServices.DirectorySearcher
                    $accountSearcher.SearchRoot = [ADSI]"LDAP://$domainNC"
                    $accountSearcher.Filter = "(distinguishedName=$accountDN)"
                    $accountSearcher.PropertiesToLoad.Clear()
                    @('samAccountName', 'adminCount', 'memberOf', 'objectSid') | ForEach-Object { [void]$accountSearcher.PropertiesToLoad.Add($_) }

                    $accountResult = $accountSearcher.FindOne()
                    if ($accountResult) {
                        $accountProps = $accountResult.Properties
                        $adminCount = if ($accountProps['admincount'] -and $accountProps['admincount'].Count -gt 0) { $accountProps['admincount'][0] } else { 0 }
                        $samAccountName = if ($accountProps['samaccountname'] -and $accountProps['samaccountname'].Count -gt 0) { $accountProps['samaccountname'][0] } else { 'Unknown' }

                        if ($adminCount -eq 1) {
                            $privilegedRevealed += $samAccountName
                        }
                    }
                    $accountSearcher.Dispose()
                } catch {
                    # Account lookup failed, continue
                }
            }

            if ($privilegedRevealed.Count -gt 0) {
                $issues += "Privileged accounts cached on RODC: $($privilegedRevealed -join ', ')"
                $severity = "CRITICAL"
            }

            $issues += "Total accounts with cached credentials: $($revealedAccounts.Count)"
        }

        # Check msDS-RevealOnDemandGroup (accounts that CAN be cached)
        $revealOnDemandGroups = @()
        if ($p['msds-revealondemandgroup'] -and $p['msds-revealondemandgroup'].Count -gt 0) {
            $revealOnDemandGroups = $p['msds-revealondemandgroup']

            # Check if any privileged groups are in RevealOnDemandGroup (should not be)
            $privilegedInRevealOnDemand = @()
            foreach ($privGroup in $privilegedGroups) {
                if ($revealOnDemandGroups -contains $privGroup) {
                    $groupName = ($privGroup -replace '^CN=([^,]+),.*', '$1')
                    $privilegedInRevealOnDemand += $groupName
                }
            }

            if ($privilegedInRevealOnDemand.Count -gt 0) {
                $issues += "Privileged groups in RevealOnDemandGroup: $($privilegedInRevealOnDemand -join ', ')"
                $severity = "CRITICAL"
            }
        }

        if ($issues.Count -gt 0 -or $neverRevealGroups.Count -eq 0) {
            if ($neverRevealGroups.Count -eq 0) {
                $issues += "No NeverRevealGroup configured (all accounts may be cacheable)"
                $severity = "CRITICAL"
            }

            $output += [PSCustomObject]@{
                Label                   = 'RODC with Insecure Credential Caching Policy'
                RODCName                = $rodcName
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }
                NeverRevealGroupCount   = $neverRevealGroups.Count
                RevealOnDemandCount     = $revealOnDemandGroups.Count
                RevealedAccountsCount   = $revealedAccounts.Count
                Issues                  = ($issues -join '; ')
                IssueCount              = $issues.Count
                Severity                = $severity
                MITRE                   = "T1552.004"
                Risk                    = "RODC compromise yields cached privileged credentials"
                Recommendation          = "Configure NeverRevealGroup to exclude all privileged accounts"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) RODCs with credential caching policy issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All RODCs have proper credential caching policies configured' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory RODC query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) RODCs with credential caching policy issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All RODCs have proper credential caching policies configured' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory RODC query failed: $_"
    exit 1
}
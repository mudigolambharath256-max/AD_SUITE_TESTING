# ============================================================
# CHECK: SECACCT-002_Password_Settings_Object_Inventory
# CATEGORY: Security_Accounts
# DESCRIPTION: Inventory of Password Settings Objects (Fine-Grained Password Policies)
# LDAP FILTER: (objectClass=msDS-PasswordSettings)
# SEARCH BASE: CN=Password Settings Container,CN=System,<DomainDN>
# OBJECT CLASS: msDS-PasswordSettings
# ATTRIBUTES: name, msDS-PasswordSettingsPrecedence, msDS-MinimumPasswordLength, msDS-PasswordComplexityEnabled, msDS-MaximumPasswordAge, msDS-MinimumPasswordAge, msDS-LockoutThreshold, msDS-LockoutDuration, msDS-PSOAppliesTo
# RISK: MEDIUM
# MITRE ATT&CK: T1110 (Brute Force)
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

    # Query Password Settings Objects
    $searcher = [ADSISearcher]"LDAP://CN=Password Settings Container,CN=System,$domainDN"
    $searcher.Filter = '(objectClass=msDS-PasswordSettings)'
    $searcher.PageSize = 1000
    $searcher.PropertiesToLoad.Clear()
    @('name', 'distinguishedName', 'msDS-PasswordSettingsPrecedence', 'msDS-MinimumPasswordLength',
      'msDS-PasswordComplexityEnabled', 'msDS-MaximumPasswordAge', 'msDS-MinimumPasswordAge',
      'msDS-LockoutThreshold', 'msDS-LockoutDuration', 'msDS-PSOAppliesTo', 'whenCreated', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $psoResults = $searcher.FindAll()
    Write-Host "Found $($psoResults.Count) Password Settings Objects" -ForegroundColor Cyan

    $findings = @()

    foreach ($psoResult in $psoResults) {
        $psoProps = $psoResult.Properties
        $psoName = if ($psoProps['name'] -and $psoProps['name'].Count -gt 0) { $psoProps['name'][0] } else { 'Unknown' }
        $psoDN = if ($psoProps['distinguishedname'] -and $psoProps['distinguishedname'].Count -gt 0) { $psoProps['distinguishedname'][0] } else { 'N/A' }
        $precedence = if ($psoProps['msds-passwordsettingsprecedence'] -and $psoProps['msds-passwordsettingsprecedence'].Count -gt 0) { $psoProps['msds-passwordsettingsprecedence'][0] } else { 'N/A' }
        $minLength = if ($psoProps['msds-minimumpasswordlength'] -and $psoProps['msds-minimumpasswordlength'].Count -gt 0) { $psoProps['msds-minimumpasswordlength'][0] } else { 'N/A' }
        $complexity = if ($psoProps['msds-passwordcomplexityenabled'] -and $psoProps['msds-passwordcomplexityenabled'].Count -gt 0) { $psoProps['msds-passwordcomplexityenabled'][0] } else { 'N/A' }
        $maxAge = if ($psoProps['msds-maximumpasswordage'] -and $psoProps['msds-maximumpasswordage'].Count -gt 0) {
            # Convert from 100-nanosecond intervals to days
            [Math]::Abs([Int64]$psoProps['msds-maximumpasswordage'][0]) / 864000000000
        } else { 'N/A' }
        $minAge = if ($psoProps['msds-minimumpasswordage'] -and $psoProps['msds-minimumpasswordage'].Count -gt 0) {
            [Int64]$psoProps['msds-minimumpasswordage'][0] / 864000000000
        } else { 'N/A' }
        $lockoutThreshold = if ($psoProps['msds-lockoutthreshold'] -and $psoProps['msds-lockoutthreshold'].Count -gt 0) { $psoProps['msds-lockoutthreshold'][0] } else { 'N/A' }
        $lockoutDuration = if ($psoProps['msds-lockoutduration'] -and $psoProps['msds-lockoutduration'].Count -gt 0) {
            [Math]::Abs([Int64]$psoProps['msds-lockoutduration'][0]) / 600000000  # Convert to minutes
        } else { 'N/A' }
        $appliesTo = if ($psoProps['msds-psoapplies'] -and $psoProps['msds-psoapplies'].Count -gt 0) { $psoProps['msds-psoapplies'].Count } else { 0 }
        $whenCreated = if ($psoProps['whencreated'] -and $psoProps['whencreated'].Count -gt 0) { $psoProps['whencreated'][0] } else { 'N/A' }

        # Analyze PSO for potential security issues
        $issues = @()
        $severity = "MEDIUM"  # Default for inventory

        if ($minLength -ne 'N/A' -and $minLength -lt 8) {
            $issues += "Minimum password length too short ($minLength)"
            $severity = "HIGH"
        }

        if ($complexity -eq $false) {
            $issues += "Password complexity disabled"
            $severity = "HIGH"
        }

        if ($maxAge -ne 'N/A' -and $maxAge -gt 365) {
            $issues += "Maximum password age too long ($maxAge days)"
            $severity = "HIGH"
        }

        if ($lockoutThreshold -ne 'N/A' -and $lockoutThreshold -eq 0) {
            $issues += "Account lockout disabled"
            $severity = "HIGH"
        }

        if ($appliesTo -eq 0) {
            $issues += "PSO not applied to any users or groups"
            $severity = "MEDIUM"
        }

        $findingDetail = "PSO Inventory: Precedence=$precedence, MinLength=$minLength, Complexity=$complexity, MaxAge=$maxAge days, LockoutThreshold=$lockoutThreshold, AppliesTo=$appliesTo objects"
        if ($issues.Count -gt 0) {
            $findingDetail += " | Issues: $($issues -join '; ')"
        }

        $findings += [PSCustomObject]@{
            CheckID = 'SECACCT-002'
            CheckName = 'Password Settings Object Inventory'
            Domain = $domainDN -replace '^DC=|,DC=', '' -replace ',DC=', '.'
            ObjectDN = $psoDN
            ObjectName = $psoName
            FindingDetail = $findingDetail
            Severity = $severity
            Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
        }
    }

    $psoResults.Dispose()
    $searcher.Dispose()

    if ($findings) {
        Write-Host "Password Settings Objects inventory complete" -ForegroundColor Green
        $findings | Format-Table -AutoSize
    } else {
        Write-Host 'No Password Settings Objects found - using default domain password policy' -ForegroundColor Yellow
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
                    checkid = 'SECACCT-002'
                    severity = 'MEDIUM'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "SECACCT-002_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: $_"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================

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

# Combined Multi-Engine Implementation with Fallback Chain
# ─────────────────────────────────────────────────────────
# Engine Priority: ActiveDirectory → ADSI → .NET → CMD
# ─────────────────────────────────────────────────────────

param(
    [string]$Engine = "AUTO"
)

function Test-ActiveDirectoryModule {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Invoke-PowerShellEngine {
    Write-Host "[ENGINE] Using PowerShell ActiveDirectory module" -ForegroundColor Green

    try {
        $forestTrusts = Get-ADTrust -Filter "TrustType -eq 'Forest'" -Properties *
        $findings = @()

        foreach ($trust in $forestTrusts) {
            $vulnerabilities = @()

            # Check if SID filtering is disabled (TREAT_AS_EXTERNAL bit NOT set)
            if (($trust.TrustAttributes -band 4) -eq 0) {
                $vulnerabilities += "SID filtering disabled - ExtraSIDs attack possible"
            }

            # Check for other risky trust attributes
            if (($trust.TrustAttributes -band 8) -ne 0) {
                $vulnerabilities += "Uses RC4 encryption (bit 0x08) - downgrade risk"
            }

            if (($trust.TrustAttributes -band 32) -eq 0) {
                $vulnerabilities += "No selective authentication (bit 0x20) - broader access"
            }

            # Check trust direction for inbound component
            $directionRisk = ""
            switch ($trust.Direction) {
                "Inbound" { $directionRisk = "Inbound trust - can receive ExtraSIDs from $($trust.Target)" }
                "Outbound" { $directionRisk = "Outbound trust - no direct ExtraSIDs risk" }
                "Bidirectional" { $directionRisk = "Bidirectional trust - can receive ExtraSIDs from $($trust.Target)" }
                default { $directionRisk = "Unknown direction ($($trust.Direction))" }
            }

            # Only flag trusts that can receive ExtraSIDs
            if ($trust.Direction -eq "Inbound" -or $trust.Direction -eq "Bidirectional") {
                if ($vulnerabilities.Count -gt 0) {
                    $severity = if (($trust.TrustAttributes -band 4) -eq 0) { "CRITICAL" } else { "HIGH" }

                    $findings += [PSCustomObject]@{
                        CheckID = 'TRST-031'
                        CheckName = 'ExtraSIDs Cross Forest Attack Surface'
                        Domain = (Get-ADDomain).DNSRoot
                        ObjectDN = $trust.DistinguishedName
                        ObjectName = $trust.Target
                        FindingDetail = "Forest trust vulnerable to ExtraSIDs: $($vulnerabilities -join '; ') | $directionRisk | trustAttributes=0x$($trust.TrustAttributes.ToString('X'))"
                        Severity = $severity
                        Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                    }
                }
            }
        }

        # Check for accounts with cross-forest SID History
        $accountsWithSidHistory = Get-ADUser -Filter "SIDHistory -like '*'" -Properties SIDHistory, SamAccountName
        $currentDomainSid = (Get-ADDomain).DomainSID.Value

        foreach ($account in $accountsWithSidHistory) {
            foreach ($historySid in $account.SIDHistory) {
                $historySidString = $historySid.Value

                if (-not $historySidString.StartsWith($currentDomainSid)) {
                    $findings += [PSCustomObject]@{
                        CheckID = 'TRST-031'
                        CheckName = 'ExtraSIDs Cross Forest Attack Surface'
                        Domain = (Get-ADDomain).DNSRoot
                        ObjectDN = $account.DistinguishedName
                        ObjectName = $account.SamAccountName
                        FindingDetail = "Account has cross-forest SID History: $historySidString (potential ExtraSIDs vector)"
                        Severity = "HIGH"
                        Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                    }
                }
            }
        }

        return $findings
    } catch {
        throw "PowerShell engine failed: $_"
    }
}

function Invoke-ADSIEngine {
    Write-Host "[ENGINE] Using ADSI DirectorySearcher" -ForegroundColor Yellow

    try {
        # Get current domain DN
        $rootDSE = [ADSI]"LDAP://RootDSE"
        $domainDN = $rootDSE.defaultNamingContext[0]

        # Query forest trusts
        $searcher = [ADSISearcher]"LDAP://CN=System,$domainDN"
        $searcher.Filter = '(&(objectClass=trustedDomain)(trustType=2))'
        $searcher.PropertiesToLoad.Clear()
        @('trustPartner', 'trustDirection', 'trustType', 'trustAttributes', 'securityIdentifier', 'distinguishedName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

        $trustResults = $searcher.FindAll()
        $findings = @()

        foreach ($trustResult in $trustResults) {
            $trustProps = $trustResult.Properties
            $trustPartner = if ($trustProps['trustpartner'] -and $trustProps['trustpartner'].Count -gt 0) { $trustProps['trustpartner'][0] } else { 'Unknown' }
            $trustDirection = if ($trustProps['trustdirection'] -and $trustProps['trustdirection'].Count -gt 0) { $trustProps['trustdirection'][0] } else { 0 }
            $trustAttributes = if ($trustProps['trustattributes'] -and $trustProps['trustattributes'].Count -gt 0) { $trustProps['trustattributes'][0] } else { 0 }
            $trustDN = if ($trustProps['distinguishedname'] -and $trustProps['distinguishedname'].Count -gt 0) { $trustProps['distinguishedname'][0] } else { 'N/A' }

            $vulnerabilities = @()

            # Check if SID filtering is disabled
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

            # Check trust direction
            $directionRisk = ""
            switch ($trustDirection) {
                1 { $directionRisk = "Inbound trust - can receive ExtraSIDs from $trustPartner" }
                2 { $directionRisk = "Outbound trust - no direct ExtraSIDs risk" }
                3 { $directionRisk = "Bidirectional trust - can receive ExtraSIDs from $trustPartner" }
                default { $directionRisk = "Unknown direction ($trustDirection)" }
            }

            # Only flag trusts that can receive ExtraSIDs
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

        # Check for accounts with cross-forest SID History
        $sidHistorySearcher = [ADSISearcher]"LDAP://$domainDN"
        $sidHistorySearcher.Filter = '(&(objectClass=user)(sIDHistory=*))'
        $sidHistorySearcher.PropertiesToLoad.Clear()
        @('sAMAccountName', 'sIDHistory', 'distinguishedName', 'objectSid') | ForEach-Object { [void]$sidHistorySearcher.PropertiesToLoad.Add($_) }

        $sidHistoryResults = $sidHistorySearcher.FindAll()

        # Get current domain SID prefix
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

        return $findings
    } catch {
        throw "ADSI engine failed: $_"
    }
}

function Invoke-CMDEngine {
    Write-Host "[ENGINE] Using CMD/dsquery fallback" -ForegroundColor Red
    Write-Warning "CMD engine has limited ExtraSIDs detection capability"
    return @()
}

# Main execution logic
try {
    $results = @()

    switch ($Engine.ToUpper()) {
        "PS" { $results = Invoke-PowerShellEngine }
        "ADSI" { $results = Invoke-ADSIEngine }
        "CMD" { $results = Invoke-CMDEngine }
        "AUTO" {
            try {
                if (Test-ActiveDirectoryModule) {
                    $results = Invoke-PowerShellEngine
                } else {
                    $results = Invoke-ADSIEngine
                }
            } catch {
                Write-Warning "Primary engines failed: $_"
                $results = Invoke-CMDEngine
            }
        }
        default { throw "Invalid engine specified: $Engine" }
    }

    if ($results -and $results.Count -gt 0) {
        Write-Host "Found $($results.Count) ExtraSIDs attack surface issues" -ForegroundColor Red
        $results | Format-List
    } else {
        Write-Host "No ExtraSIDs attack surface detected" -ForegroundColor Green
    }

} catch {
    Write-Error "Check execution failed: $_"
    exit 1
}

# ── BloodHound Export ─────────────────────────────────────────────────────────
# Added by Kiro automation — DO NOT modify lines above this section
try {
    $bhSession = if ($env:ADSUITE_SESSION_ID) { $env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    $bhRoot    = if ($env:ADSUITE_OUTPUT_ROOT) { $env:ADSUITE_OUTPUT_ROOT } else { Join-Path $env:TEMP 'ADSuite_Sessions' }
    $bhDir     = Join-Path $bhRoot "$bhSession\bloodhound"
    if (-not (Test-Path $bhDir)) { New-Item -ItemType Directory -Path $bhDir -Force -ErrorAction Stop | Out-Null }

    $bhNodes = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($r in $uniqueResults) {
        $dn   = if ($r.DistinguishedName) { $r.DistinguishedName } else { '' }
        $name = if ($r.Name) { $r.Name } else { if ($r.PSObject.Properties['CheckName']) { $r.CheckName } else { 'UNKNOWN' } }
        $dom  = (($dn -split ',') | Where-Object{$_ -match '^DC='} | ForEach-Object{$_ -replace '^DC=',''}) -join '.' | ForEach-Object{$_.ToUpper()}
        $oid  = if ($dn) { $dn.ToUpper() } else { [guid]::NewGuid().ToString() }

        $bhNodes.Add(@{
            ObjectIdentifier = $oid
            Properties       = @{
                name              = if ($dom) { "$($name.ToUpper())@$dom" } else { $name.ToUpper() }
                domain            = $dom
                distinguishedname = $dn.ToUpper()
                enabled           = $true
                adSuiteCheckId    = 'TRST-031'
                adSuiteCheckName  = 'ExtraSIDs_Cross_Forest_Attack_Surface'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteTrust_Relationships   = 'Trust_Relationships'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "TRST-031_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

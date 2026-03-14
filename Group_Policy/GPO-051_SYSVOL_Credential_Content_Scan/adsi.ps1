# Check: SYSVOL Credential Content Scan
# Category: Group Policy
# Severity: critical
# ID: GPO-051
# Requirements: None
# ============================================
# Scan SYSVOL for hardcoded credentials in Group Policy files

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + File System
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
    $domainName = ($domainNC -replace 'DC=', '' -replace ',', '.')

    # Get GPO metadata from AD
    $gpoSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $gpoSearcher.SearchRoot = [ADSI]"LDAP://CN=Policies,CN=System,$domainNC"
    $gpoSearcher.Filter = '(objectClass=groupPolicyContainer)'
    $gpoSearcher.PageSize = 1000
    $gpoSearcher.PropertiesToLoad.Clear()
    @('displayName', 'distinguishedName', 'gPCFileSysPath', 'whenChanged', 'cn', 'objectSid', 'samAccountName') | ForEach-Object { [void]$gpoSearcher.PropertiesToLoad.Add($_) }

    $gpoResults = $gpoSearcher.FindAll()
    Write-Host "Found $($gpoResults.Count) Group Policy Objects" -ForegroundColor Cyan

    # Construct SYSVOL path
    $sysvolPath = "\\$domainName\SYSVOL\$domainName\Policies"
    Write-Host "Scanning SYSVOL path: $sysvolPath" -ForegroundColor Cyan

    if (-not (Test-Path $sysvolPath)) {
        Write-Warning "SYSVOL path not accessible: $sysvolPath"
        Write-Host "This check requires access to the SYSVOL share" -ForegroundColor Yellow
        return
    }

    $output = @()

    # Files to scan for GPP credentials
    $gppFiles = @(
        "Groups.xml",
        "ScheduledTasks.xml",
        "Services.xml",
        "DataSources.xml",
        "Printers.xml",
        "Drives.xml"
    )

    # Script files to scan for hardcoded credentials
    $scriptExtensions = @("*.bat", "*.cmd", "*.vbs", "*.ps1")

    # Credential patterns to search for
    $credentialPatterns = @{
        "GPP_cpassword" = 'cpassword="([^"]+)"'
        "Password_Assignment" = '(?i)(password\s*=\s*["\']?)([^"\s\r\n]+)'
        "Net_Use_Password" = '(?i)net\s+use\s+.*\s+([^"\s]+)\s*/user:'
        "ConvertTo_SecureString" = '(?i)ConvertTo-SecureString\s+-String\s+["\']([^"\']+)["\']'
        "Credential_Variable" = '(?i)\$\w*(?:password|pwd|cred)\w*\s*=\s*["\']([^"\']+)["\']'
    }

    # Scan each GPO folder
    foreach ($gpo in $gpoResults) {
        $gpoProps = $gpo.Properties
        $gpoName = if ($gpoProps['displayname'] -and $gpoProps['displayname'].Count -gt 0) { $gpoProps['displayname'][0] } else { 'Unknown' }
        $gpoGuid = if ($gpoProps['cn'] -and $gpoProps['cn'].Count -gt 0) { $gpoProps['cn'][0] } else { 'Unknown' }

        $gpoPath = Join-Path $sysvolPath $gpoGuid

        if (Test-Path $gpoPath) {
            # Scan GPP XML files
            foreach ($gppFile in $gppFiles) {
                $gppFiles = Get-ChildItem -Path $gpoPath -Recurse -Name $gppFile -ErrorAction SilentlyContinue

                foreach ($file in $gppFiles) {
                    $fullPath = Join-Path $gpoPath $file
                    try {
                        $content = Get-Content $fullPath -Raw -ErrorAction Stop

                        # Check for cpassword attribute
                        if ($content -match $credentialPatterns["GPP_cpassword"]) {
                            $matches = [regex]::Matches($content, $credentialPatterns["GPP_cpassword"])
                            foreach ($match in $matches) {
                                $cpassword = $match.Groups[1].Value
                                if ($cpassword -and $cpassword.Length -gt 0) {
                                    $output += [PSCustomObject]@{
                                        Label           = 'SYSVOL Credential Found'
                                        GPOName         = $gpoName
                                        GPOGUID         = $gpoGuid
                                        FilePath        = $fullPath
                                        FileName        = $file
                                        CredentialType  = "GPP cpassword"
                                        MaskedValue     = $cpassword.Substring(0, [Math]::Min(8, $cpassword.Length)) + "..."
                                        LineNumber      = "Multiple possible"
                                        Severity        = "CRITICAL"
                                        CVE             = "CVE-2014-1812"
                                        MITRE           = "T1552.006"
                                        Risk            = "Encrypted password with known AES key"
                                        Recommendation  = "Remove cpassword attributes, use alternative methods"
                                    }
                                }
                            }
                        }
                    } catch {
                        Write-Warning "Unable to read file: $fullPath"
                    }
                }
            }

            # Scan script files
            foreach ($extension in $scriptExtensions) {
                $scriptFiles = Get-ChildItem -Path $gpoPath -Recurse -Include $extension -ErrorAction SilentlyContinue

                foreach ($scriptFile in $scriptFiles) {
                    try {
                        $lines = Get-Content $scriptFile.FullName -ErrorAction Stop
                        $lineNumber = 0

                        foreach ($line in $lines) {
                            $lineNumber++

                            foreach ($patternName in $credentialPatterns.Keys) {
                                if ($patternName -eq "GPP_cpassword") { continue } # Already checked above

                                $pattern = $credentialPatterns[$patternName]
                                if ($line -match $pattern) {
                                    $credValue = $matches[1]
                                    if ($credValue -and $credValue.Length -gt 3) {
                                        $output += [PSCustomObject]@{
                                            Label           = 'SYSVOL Credential Found'
                                            GPOName         = $gpoName
                                            GPOGUID         = $gpoGuid
                                            FilePath        = $scriptFile.FullName
                                            FileName        = $scriptFile.Name
                                            CredentialType  = $patternName.Replace('_', ' ')
                                            MaskedValue     = $credValue.Substring(0, [Math]::Min(4, $credValue.Length)) + "***"
                                            LineNumber      = $lineNumber
                                            Severity        = "HIGH"
                                            CVE             = "N/A"
                                            MITRE           = "T1552.001"
                                            Risk            = "Hardcoded credentials in SYSVOL scripts"
                                            Recommendation  = "Remove hardcoded credentials, use secure alternatives"
                                        }
                                    }
                                }
                            }
                        }
                    } catch {
                        Write-Warning "Unable to read script file: $($scriptFile.FullName)"
                    }
                }
            }
        }
    }

    $gpoResults.Dispose()
    $gpoSearcher.Dispose()

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
                    checkid = 'GPO-051'
                    severity = 'critical'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "GPO-051_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: SYSVOL Credential Content Scan
# Category: Group Policy
# Severity: critical
# ID: GPO-051
# Requirements: None
# ============================================
# Scan SYSVOL for hardcoded credentials in Group Policy files

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : LDAP + File System
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
    $domainName = ($domainNC -replace 'DC=', '' -replace ',', '.')

    # Get GPO metadata from AD
    $gpoSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $gpoSearcher.SearchRoot = [ADSI]"LDAP://CN=Policies,CN=System,$domainNC"
    $gpoSearcher.Filter = '(objectClass=groupPolicyContainer)'
    $gpoSearcher.PageSize = 1000
    $gpoSearcher.PropertiesToLoad.Clear()
    @('displayName', 'distinguishedName', 'gPCFileSysPath', 'whenChanged', 'cn', 'objectSid', 'samAccountName') | ForEach-Object { [void]$gpoSearcher.PropertiesToLoad.Add($_) }

    $gpoResults = $gpoSearcher.FindAll()
    Write-Host "Found $($gpoResults.Count) Group Policy Objects" -ForegroundColor Cyan

    # Construct SYSVOL path
    $sysvolPath = "\\$domainName\SYSVOL\$domainName\Policies"
    Write-Host "Scanning SYSVOL path: $sysvolPath" -ForegroundColor Cyan

    if (-not (Test-Path $sysvolPath)) {
        Write-Warning "SYSVOL path not accessible: $sysvolPath"
        Write-Host "This check requires access to the SYSVOL share" -ForegroundColor Yellow
        return
    }

    $output = @()

    # Files to scan for GPP credentials
    $gppFiles = @(
        "Groups.xml",
        "ScheduledTasks.xml",
        "Services.xml",
        "DataSources.xml",
        "Printers.xml",
        "Drives.xml"
    )

    # Script files to scan for hardcoded credentials
    $scriptExtensions = @("*.bat", "*.cmd", "*.vbs", "*.ps1")

    # Credential patterns to search for
    $credentialPatterns = @{
        "GPP_cpassword" = 'cpassword="([^"]+)"'
        "Password_Assignment" = '(?i)(password\s*=\s*["\']?)([^"\s\r\n]+)'
        "Net_Use_Password" = '(?i)net\s+use\s+.*\s+([^"\s]+)\s*/user:'
        "ConvertTo_SecureString" = '(?i)ConvertTo-SecureString\s+-String\s+["\']([^"\']+)["\']'
        "Credential_Variable" = '(?i)\$\w*(?:password|pwd|cred)\w*\s*=\s*["\']([^"\']+)["\']'
    }

    # Scan each GPO folder
    foreach ($gpo in $gpoResults) {
        $gpoProps = $gpo.Properties
        $gpoName = if ($gpoProps['displayname'] -and $gpoProps['displayname'].Count -gt 0) { $gpoProps['displayname'][0] } else { 'Unknown' }
        $gpoGuid = if ($gpoProps['cn'] -and $gpoProps['cn'].Count -gt 0) { $gpoProps['cn'][0] } else { 'Unknown' }

        $gpoPath = Join-Path $sysvolPath $gpoGuid

        if (Test-Path $gpoPath) {
            # Scan GPP XML files
            foreach ($gppFile in $gppFiles) {
                $gppFiles = Get-ChildItem -Path $gpoPath -Recurse -Name $gppFile -ErrorAction SilentlyContinue

                foreach ($file in $gppFiles) {
                    $fullPath = Join-Path $gpoPath $file
                    try {
                        $content = Get-Content $fullPath -Raw -ErrorAction Stop

                        # Check for cpassword attribute
                        if ($content -match $credentialPatterns["GPP_cpassword"]) {
                            $matches = [regex]::Matches($content, $credentialPatterns["GPP_cpassword"])
                            foreach ($match in $matches) {
                                $cpassword = $match.Groups[1].Value
                                if ($cpassword -and $cpassword.Length -gt 0) {
                                    $output += [PSCustomObject]@{
                                        Label           = 'SYSVOL Credential Found'
                                        GPOName         = $gpoName
                                        GPOGUID         = $gpoGuid
                                        FilePath        = $fullPath
                                        FileName        = $file
                                        CredentialType  = "GPP cpassword"
                                        MaskedValue     = $cpassword.Substring(0, [Math]::Min(8, $cpassword.Length)) + "..."
                                        LineNumber      = "Multiple possible"
                                        Severity        = "CRITICAL"
                                        CVE             = "CVE-2014-1812"
                                        MITRE           = "T1552.006"
                                        Risk            = "Encrypted password with known AES key"
                                        Recommendation  = "Remove cpassword attributes, use alternative methods"
                                    }
                                }
                            }
                        }
                    } catch {
                        Write-Warning "Unable to read file: $fullPath"
                    }
                }
            }

            # Scan script files
            foreach ($extension in $scriptExtensions) {
                $scriptFiles = Get-ChildItem -Path $gpoPath -Recurse -Include $extension -ErrorAction SilentlyContinue

                foreach ($scriptFile in $scriptFiles) {
                    try {
                        $lines = Get-Content $scriptFile.FullName -ErrorAction Stop
                        $lineNumber = 0

                        foreach ($line in $lines) {
                            $lineNumber++

                            foreach ($patternName in $credentialPatterns.Keys) {
                                if ($patternName -eq "GPP_cpassword") { continue } # Already checked above

                                $pattern = $credentialPatterns[$patternName]
                                if ($line -match $pattern) {
                                    $credValue = $matches[1]
                                    if ($credValue -and $credValue.Length -gt 3) {
                                        $output += [PSCustomObject]@{
                                            Label           = 'SYSVOL Credential Found'
                                            GPOName         = $gpoName
                                            GPOGUID         = $gpoGuid
                                            FilePath        = $scriptFile.FullName
                                            FileName        = $scriptFile.Name
                                            CredentialType  = $patternName.Replace('_', ' ')
                                            MaskedValue     = $credValue.Substring(0, [Math]::Min(4, $credValue.Length)) + "***"
                                            LineNumber      = $lineNumber
                                            Severity        = "HIGH"
                                            CVE             = "N/A"
                                            MITRE           = "T1552.001"
                                            Risk            = "Hardcoded credentials in SYSVOL scripts"
                                            Recommendation  = "Remove hardcoded credentials, use secure alternatives"
                                        }
                                    }
                                }
                            }
                        }
                    } catch {
                        Write-Warning "Unable to read script file: $($scriptFile.FullName)"
                    }
                }
            }
        }
    }

    $gpoResults.Dispose()
    $gpoSearcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        $criticalCount = ($output | Where-Object { $_.Severity -eq "CRITICAL" }).Count
        $highCount = ($output | Where-Object { $_.Severity -eq "HIGH" }).Count

        Write-Host "`nSummary: Found $($output.Count) credential exposures in SYSVOL" -ForegroundColor Red
        Write-Host "  - Critical (GPP cpassword): $criticalCount" -ForegroundColor Red
        Write-Host "  - High (Script credentials): $highCount" -ForegroundColor Red
        Write-Host "`nIMMEDIATE ACTION REQUIRED: Remove all credentials from SYSVOL files" -ForegroundColor Red
    } else {
        Write-Host 'No findings - No credentials detected in SYSVOL content' -ForegroundColor Green
    }
} catch {
    Write-Error "SYSVOL credential scan failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        $criticalCount = ($output | Where-Object { $_.Severity -eq "CRITICAL" }).Count
        $highCount = ($output | Where-Object { $_.Severity -eq "HIGH" }).Count

        Write-Host "`nSummary: Found $($output.Count) credential exposures in SYSVOL" -ForegroundColor Red
        Write-Host "  - Critical (GPP cpassword): $criticalCount" -ForegroundColor Red
        Write-Host "  - High (Script credentials): $highCount" -ForegroundColor Red
        Write-Host "`nIMMEDIATE ACTION REQUIRED: Remove all credentials from SYSVOL files" -ForegroundColor Red
    } else {
        Write-Host 'No findings - No credentials detected in SYSVOL content' -ForegroundColor Green
    }
} catch {
    Write-Error "SYSVOL credential scan failed: $_"
    exit 1
}
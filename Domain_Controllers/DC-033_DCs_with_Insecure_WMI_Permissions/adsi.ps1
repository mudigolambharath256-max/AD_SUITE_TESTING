# Check: DCs with Insecure WMI Permissions
# Category: Domain Controllers
# Severity: medium
# ID: DC-033
# Requirements: None
# ============================================
# Check WMI namespace permissions: [WMIClass]"\\$dc\root:__SystemSecurity"

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP + WMI
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $searcher.Filter     = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $searcher.PageSize   = 1000
    $searcher.PropertiesToLoad.Clear()
    (@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'userAccountControl', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) Domain Controllers" -ForegroundColor Cyan

    $output = @()

    foreach ($result in $results) {
        $p = $result.Properties
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        if ($dnsHostName -eq 'N/A') {
            Write-Warning "Skipping DC with no DNS hostname: $($p['name'][0])"
            continue
        }

        try {
            # Check WMI namespace security
            $wmiNamespaces = @("root\CIMV2", "root\CIMv2\Security", "root\Microsoft\Windows\ServerManager")
            $suspiciousPermissions = @()

            foreach ($namespace in $wmiNamespaces) {
                try {
                    # Get WMI namespace security descriptor
                    $wmiSecurity = Get-WmiObject -Class __SystemSecurity -Namespace $namespace -ComputerName $dnsHostName -ErrorAction SilentlyContinue

                    if ($wmiSecurity) {
                        $sd = $wmiSecurity.PsBase.InvokeMethod("GetSD", $null, $null)

                        if ($sd -and $sd.Descriptor) {
                            $dacl = $sd.Descriptor.DACL

                            foreach ($ace in $dacl) {
                                $trustee = $ace.Trustee
                                $accessMask = $ace.AccessMask

                                # Check for suspicious permissions
                                # AccessMask values: 1=Execute Methods, 2=Full Write, 4=Partial Write, 8=Provider Write, 16=Enable Account, 32=Remote Access
                                if ($trustee.Name -and $trustee.Name -notmatch '^(SYSTEM|Administrators|LOCAL SERVICE|NETWORK SERVICE|WinRM Virtual Users)$') {
                                    if ($accessMask -band 32) { # Remote Access
                                        $suspiciousPermissions += "$namespace - $($trustee.Name) has Remote Access"
                                    }
                                    if ($accessMask -band 1) { # Execute Methods
                                        $suspiciousPermissions += "$namespace - $($trustee.Name) has Execute Methods"
                                    }
                                    if ($accessMask -band 2) { # Full Write
                                        $suspiciousPermissions += "$namespace - $($trustee.Name) has Full Write"
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    # Namespace access failed, continue
                }
            }

            # Also check DCOM permissions for WMI
            try {
                $dcomConfig = Get-WmiObject -Class Win32_DCOMApplicationSetting -ComputerName $dnsHostName -Filter "DisplayName='Windows Management Instrumentation'" -ErrorAction SilentlyContinue
                if (-not $dcomConfig) {
                    $suspiciousPermissions += "Unable to verify DCOM WMI configuration"
                }
            } catch {
                $suspiciousPermissions += "DCOM WMI configuration check failed"
            }

            if ($suspiciousPermissions.Count -gt 0) {
                $severity = "MEDIUM"
                if ($suspiciousPermissions -match "Full Write|Execute Methods") {
                    $severity = "HIGH"
                }

                $output += [PSCustomObject]@{
                    Label                   = 'DC with Insecure WMI Permissions'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    SuspiciousPermissions   = ($suspiciousPermissions -join '; ')
                    PermissionCount         = $suspiciousPermissions.Count
                    Severity                = $severity
                    Risk                    = "Unauthorized WMI access, potential lateral movement"
                    Recommendation          = "Review and restrict WMI namespace permissions"
                }
            }
        } catch {
            Write-Warning "Unable to check WMI permissions on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC WMI Permission Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                SuspiciousPermissions   = "Access Denied"
                PermissionCount         = "Unknown"
                Severity                = "UNKNOWN"
                Risk                    = "Unable to verify WMI security"
                Recommendation          = "Manual WMI permission verification required"
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
                    checkid = 'DC-033'
                    severity = 'medium'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-033_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: # Check: DCs with Insecure WMI Permissions
# Category: Domain Controllers
# Severity: medium
# ID: DC-033
# Requirements: None
# ============================================
# Check WMI namespace permissions: [WMIClass]"\\$dc\root:__SystemSecurity"

# LDAP search (ADSI / DirectorySearcher)
# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP + WMI
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

try {
    $root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://$domainNC"
    $searcher.Filter     = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $searcher.PageSize   = 1000
    $searcher.PropertiesToLoad.Clear()
    (@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'userAccountControl', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

    $results = $searcher.FindAll()
    Write-Host "Found $($results.Count) Domain Controllers" -ForegroundColor Cyan

    $output = @()

    foreach ($result in $results) {
        $p = $result.Properties
        $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { 'N/A' }

        if ($dnsHostName -eq 'N/A') {
            Write-Warning "Skipping DC with no DNS hostname: $($p['name'][0])"
            continue
        }

        try {
            # Check WMI namespace security
            $wmiNamespaces = @("root\CIMV2", "root\CIMv2\Security", "root\Microsoft\Windows\ServerManager")
            $suspiciousPermissions = @()

            foreach ($namespace in $wmiNamespaces) {
                try {
                    # Get WMI namespace security descriptor
                    $wmiSecurity = Get-WmiObject -Class __SystemSecurity -Namespace $namespace -ComputerName $dnsHostName -ErrorAction SilentlyContinue

                    if ($wmiSecurity) {
                        $sd = $wmiSecurity.PsBase.InvokeMethod("GetSD", $null, $null)

                        if ($sd -and $sd.Descriptor) {
                            $dacl = $sd.Descriptor.DACL

                            foreach ($ace in $dacl) {
                                $trustee = $ace.Trustee
                                $accessMask = $ace.AccessMask

                                # Check for suspicious permissions
                                # AccessMask values: 1=Execute Methods, 2=Full Write, 4=Partial Write, 8=Provider Write, 16=Enable Account, 32=Remote Access
                                if ($trustee.Name -and $trustee.Name -notmatch '^(SYSTEM|Administrators|LOCAL SERVICE|NETWORK SERVICE|WinRM Virtual Users)$') {
                                    if ($accessMask -band 32) { # Remote Access
                                        $suspiciousPermissions += "$namespace - $($trustee.Name) has Remote Access"
                                    }
                                    if ($accessMask -band 1) { # Execute Methods
                                        $suspiciousPermissions += "$namespace - $($trustee.Name) has Execute Methods"
                                    }
                                    if ($accessMask -band 2) { # Full Write
                                        $suspiciousPermissions += "$namespace - $($trustee.Name) has Full Write"
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    # Namespace access failed, continue
                }
            }

            # Also check DCOM permissions for WMI
            try {
                $dcomConfig = Get-WmiObject -Class Win32_DCOMApplicationSetting -ComputerName $dnsHostName -Filter "DisplayName='Windows Management Instrumentation'" -ErrorAction SilentlyContinue
                if (-not $dcomConfig) {
                    $suspiciousPermissions += "Unable to verify DCOM WMI configuration"
                }
            } catch {
                $suspiciousPermissions += "DCOM WMI configuration check failed"
            }

            if ($suspiciousPermissions.Count -gt 0) {
                $severity = "MEDIUM"
                if ($suspiciousPermissions -match "Full Write|Execute Methods") {
                    $severity = "HIGH"
                }

                $output += [PSCustomObject]@{
                    Label                   = 'DC with Insecure WMI Permissions'
                    Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                    DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    DNSHostName             = $dnsHostName
                    OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                    SuspiciousPermissions   = ($suspiciousPermissions -join '; ')
                    PermissionCount         = $suspiciousPermissions.Count
                    Severity                = $severity
                    Risk                    = "Unauthorized WMI access, potential lateral movement"
                    Recommendation          = "Review and restrict WMI namespace permissions"
                }
            }
        } catch {
            Write-Warning "Unable to check WMI permissions on ${dnsHostName}: $_"
            $output += [PSCustomObject]@{
                Label                   = 'DC WMI Permission Check Failed'
                Name                    = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                DistinguishedName       = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                DNSHostName             = $dnsHostName
                OperatingSystem         = if ($p['operatingsystem'] -and $p['operatingsystem'].Count -gt 0) { $p['operatingsystem'][0] } else { 'N/A' }
                SuspiciousPermissions   = "Access Denied"
                PermissionCount         = "Unknown"
                Severity                = "UNKNOWN"
                Risk                    = "Unable to verify WMI security"
                Recommendation          = "Manual WMI permission verification required"
            }
        }
    }

    $results.Dispose()
    $searcher.Dispose()

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with WMI permission issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper WMI permissions' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with WMI permission issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have proper WMI permissions' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
}
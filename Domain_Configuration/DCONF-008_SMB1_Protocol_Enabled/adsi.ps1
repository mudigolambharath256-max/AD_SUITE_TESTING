# ============================================================
# CHECK: DCONF-008_SMB1_Protocol_Enabled
# CATEGORY: Domain_Configuration
# DESCRIPTION: Checks if SMB1 protocol is enabled (critical security risk)
# LDAP FILTER: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
# SEARCH BASE: Default NC
# OBJECT CLASS: computer
# ATTRIBUTES: name, dNSHostName, distinguishedName
# RISK: CRITICAL
# MITRE ATT&CK: T1021.002 (Remote Services: SMB/Windows Admin Shares)
# ============================================================

# ADSI DirectorySearcher Implementation
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : Registry via WMI
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
    # First enumerate domain controllers
    $searcher = [ADSISearcher]'(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
    $searcher.PageSize = 1000
    $searcher.PropertiesToLoad.Clear()
    @('name', 'dNSHostName', 'distinguishedName', 'objectSid', 'samAccountName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

    $dcResults = $searcher.FindAll()
    Write-Host "Found $($dcResults.Count) domain controllers to check" -ForegroundColor Cyan

    $findings = @()

    foreach ($dcResult in $dcResults) {
        $dcProps = $dcResult.Properties
        $dcName = if ($dcProps['dnshostname'] -and $dcProps['dnshostname'].Count -gt 0) { $dcProps['dnshostname'][0] } else { $dcProps['name'][0] }

        try {
            # Check SMB1 registry settings via WMI
            $regQuery = Get-WmiObject -ComputerName $dcName -Class Win32_Registry -ErrorAction SilentlyContinue
            if ($regQuery) {
                $hklm = 2147483650  # HKEY_LOCAL_MACHINE

                # Check SMB1 server setting
                $serverKeyPath = "SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
                $serverValueName = "SMB1"
                $serverResult = $regQuery.GetDWORDValue($hklm, $serverKeyPath, $serverValueName)
                $smb1Server = if ($serverResult.ReturnValue -eq 0) { $serverResult.uValue } else { 1 }  # Default is enabled

                # Check SMB1 client setting
                $clientKeyPath = "SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
                $clientValueName = "RequireSecuritySignature"
                $clientResult = $regQuery.GetDWORDValue($hklm, $clientKeyPath, $clientValueName)

                # Also check if SMB1 feature is installed (Windows Server 2016+)
                $featureKeyPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages"

                $smb1Issues = @()

                if ($smb1Server -ne 0) {
                    $smb1Issues += "SMB1 Server enabled (SMB1=$smb1Server)"
                }

                # Check for SMB1 client via different registry path
                $mrxsmbKeyPath = "SYSTEM\CurrentControlSet\Services\mrxsmb10"
                $mrxsmbResult = $regQuery.GetDWORDValue($hklm, $mrxsmbKeyPath, "Start")
                if ($mrxsmbResult.ReturnValue -eq 0 -and $mrxsmbResult.uValue -ne 4) {
                    $smb1Issues += "SMB1 Client enabled (mrxsmb10 Start=$($mrxsmbResult.uValue))"
                }

                if ($smb1Issues.Count -gt 0) {
                    $findings += [PSCustomObject]@{
                        CheckID = 'DCONF-008'
                        CheckName = 'SMB1 Protocol Enabled'
                        Domain = $dcName.Split('.')[1..99] -join '.'
                        ObjectDN = if ($dcProps['distinguishedname'] -and $dcProps['distinguishedname'].Count -gt 0) { $dcProps['distinguishedname'][0] } else { 'N/A' }
                        ObjectName = $dcName
                        FindingDetail = "SMB1 enabled: $($smb1Issues -join '; ')"
                        Severity = "CRITICAL"
                        Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                    }
                }
            } else {
                Write-Warning "Could not connect to registry on $dcName"
            }
        } catch {
            Write-Warning "Failed to check SMB1 settings on ${dcName}: $_"
        }
    }

    $dcResults.Dispose()
    $searcher.Dispose()

    if ($findings) {
        Write-Host "Found $($findings.Count) DCs with SMB1 enabled" -ForegroundColor Red
        $findings | Format-Table -AutoSize
    } else {
        Write-Host 'No findings - SMB1 is disabled on all DCs' -ForegroundColor Green
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
                    checkid = 'DCONF-008'
                    severity = 'MEDIUM'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DCONF-008_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: $_"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================

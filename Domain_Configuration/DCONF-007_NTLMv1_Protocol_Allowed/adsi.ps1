# ============================================================
# CHECK: DCONF-007_NTLMv1_Protocol_Allowed
# CATEGORY: Domain_Configuration
# DESCRIPTION: Checks if NTLMv1 authentication is allowed (security risk)
# LDAP FILTER: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
# SEARCH BASE: Default NC
# OBJECT CLASS: computer
# ATTRIBUTES: name, dNSHostName, distinguishedName
# RISK: HIGH
# MITRE ATT&CK: T1557.001 (LLMNR/NBT-NS Poisoning and SMB Relay)
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
            # Check LmCompatibilityLevel registry setting via WMI
            $regQuery = Get-WmiObject -ComputerName $dcName -Class Win32_Registry -ErrorAction SilentlyContinue
            if ($regQuery) {
                $hklm = 2147483650  # HKEY_LOCAL_MACHINE
                $keyPath = "SYSTEM\CurrentControlSet\Control\Lsa"
                $valueName = "LmCompatibilityLevel"

                $regValue = $regQuery.GetDWORDValue($hklm, $keyPath, $valueName)
                $lmLevel = if ($regValue.ReturnValue -eq 0) { $regValue.uValue } else { 0 }  # Default is 0 if not set

                # LmCompatibilityLevel values:
                # 0 = Send LM and NTLM responses
                # 1 = Send LM and NTLM - use NTLMv2 session security if negotiated
                # 2 = Send NTLM response only
                # 3 = Send NTLMv2 response only
                # 4 = Send NTLMv2 response only, refuse LM
                # 5 = Send NTLMv2 response only, refuse LM and NTLM

                if ($lmLevel -lt 5) {
                    $levelDescription = switch ($lmLevel) {
                        0 { "Send LM and NTLM responses (CRITICAL)" }
                        1 { "Send LM and NTLM with NTLMv2 session security (HIGH)" }
                        2 { "Send NTLM response only (HIGH)" }
                        3 { "Send NTLMv2 response only (MEDIUM)" }
                        4 { "Send NTLMv2 response only, refuse LM (MEDIUM)" }
                        default { "Unknown level $lmLevel" }
                    }

                    $severity = if ($lmLevel -le 2) { "CRITICAL" } elseif ($lmLevel -le 4) { "HIGH" } else { "MEDIUM" }

                    $findings += [PSCustomObject]@{
                        CheckID = 'DCONF-007'
                        CheckName = 'NTLMv1 Protocol Allowed'
                        Domain = $dcName.Split('.')[1..99] -join '.'
                        ObjectDN = if ($dcProps['distinguishedname'] -and $dcProps['distinguishedname'].Count -gt 0) { $dcProps['distinguishedname'][0] } else { 'N/A' }
                        ObjectName = $dcName
                        FindingDetail = "LmCompatibilityLevel: $lmLevel - $levelDescription"
                        Severity = $severity
                        Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                    }
                }
            } else {
                Write-Warning "Could not connect to registry on $dcName"
            }
        } catch {
            Write-Warning "Failed to check NTLMv1 settings on ${dcName}: $_"
        }
    }

    $dcResults.Dispose()
    $searcher.Dispose()

    if ($findings) {
        Write-Host "Found $($findings.Count) DCs with NTLMv1 allowed" -ForegroundColor Yellow
        $findings | Format-Table -AutoSize
    } else {
        Write-Host 'No findings - all DCs have NTLMv2-only configuration' -ForegroundColor Green
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
                    checkid = 'DCONF-007'
                    severity = 'MEDIUM'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DCONF-007_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: $_"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================

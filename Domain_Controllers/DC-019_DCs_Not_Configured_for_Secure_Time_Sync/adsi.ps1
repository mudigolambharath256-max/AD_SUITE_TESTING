# DC-043: DCs Not Configured for Secure Time Sync (ADSI Version)
# No external dependencies required

# ─────────────────────────────────────────────
# DetectionConfidence : Medium
# DataSource          : LDAP
# FalsePositiveRisk   : Medium
# ─────────────────────────────────────────────

$results = @()

try {
    # Get Domain
    $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
    $domainDN = "DC=" + ($domain.Name -replace "\.", ",DC=")

    # LDAP filter for Domain Controllers
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = "LDAP://$domainDN"
    $searcher.Filter = "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))"
    $searcher.PropertiesToLoad.AddRange(@("name", "dNSHostName", "distinguishedName", "objectSid", "samAccountName"))
    $searcher.PageSize = 1000

    $dcs = $searcher.FindAll()

    # Get PDC Emulator
    $pdcEmulator = $domain.PdcRoleOwner.Name

    foreach ($dc in $dcs) {
        $name = $dc.Properties["name"][0]
        $hostname = $dc.Properties["dnshostname"][0]
        $isPDC = ($hostname -eq $pdcEmulator)

        Write-Host "Checking $hostname..." -ForegroundColor Cyan

        # Test connectivity
        if (-not (Test-Connection -ComputerName $hostname -Count 1 -Quiet)) {
            Write-Verbose "$hostname is unreachable"
            continue
        }

        try {
            # Check W32Time service
            $w32timeService = Get-Service -Name W32Time -ComputerName $hostname -ErrorAction Stop

            # Get time configuration
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $hostname)
            $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\W32Time\Parameters')

            if ($regKey) {
                $type = $regKey.GetValue('Type')
                $ntpServer = $regKey.GetValue('NtpServer')
                $regKey.Close()
            }
            $reg.Close()

            # Get current time source
            $timeSource = $null
            try {
                $timeSource = Invoke-Command -ComputerName $hostname -ScriptBlock {
                    (w32tm /query /source 2>&1) -join ''
                } -ErrorAction SilentlyContinue
            } catch {
                $timeSource = "Unable to query"
            }

            # Determine issues
            $issues = @()

            if ($w32timeService.Status -ne 'Running') {
                $issues += "W32Time service not running"
            }

            if ($isPDC) {
                if ($type -ne 'NTP') {
                    $issues += "PDC not configured for NTP (Type: $type)"
                }
                if ([string]::IsNullOrEmpty($ntpServer) -or $ntpServer -eq ',0x0') {
                    $issues += "PDC has no NTP server configured"
                }
            } else {
                if ($type -ne 'NT5DS') {
                    $issues += "Non-PDC not using domain hierarchy (Type: $type)"
                }
            }

            if ($issues.Count -gt 0) {
                $results += [PSCustomObject]@{
                    Name = $name
                    HostName = $hostname
                    IsPDC = $isPDC
                    ServiceStatus = $w32timeService.Status
                    TimeSourceType = $type
                    NTPServer = $ntpServer
                    CurrentSource = $timeSource
                    Issues = ($issues -join '; ')
                    Label = 'DC-043'
                    Check = 'DCs Not Configured for Secure Time Sync'
                    Engine = 'ADSI'
                }
            }

        } catch {
            Write-Verbose "Error checking $hostname : $_"
        }
    }

    $dcs.Dispose()
    $searcher.Dispose()

    # Display results
    if ($results.Count -gt 0) {
        Write-Host "`nDomain Controllers with Time Sync Issues:" -ForegroundColor Red
        $results | Format-Table -AutoSize

    } else {
        Write-Host "`nNo Domain Controllers with time sync issues found." -ForegroundColor Green
    }

} catch {
    Write-Error "Error executing check: $_"
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
                    checkid = 'DC-019'
                    severity = 'MEDIUM'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "DC-019_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: $_"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================

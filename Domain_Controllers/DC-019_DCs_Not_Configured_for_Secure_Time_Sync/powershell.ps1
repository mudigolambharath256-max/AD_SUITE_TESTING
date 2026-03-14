# DC-043: DCs Not Configured for Secure Time Sync
# Identifies Domain Controllers with insecure or misconfigured time synchronization

Import-Module ActiveDirectory -ErrorAction Stop

$results = @()

try {
    # Get all Domain Controllers
    $dcs = Get-ADDomainController -Filter * | Select-Object Name, HostName, OperationMasterRoles

    # Get PDC Emulator
    $pdcEmulator = ($dcs | Where-Object { $_.OperationMasterRoles -contains 'PDCEmulator' }).HostName

    foreach ($dc in $dcs) {
        $hostname = $dc.HostName
        $isPDC = $dc.OperationMasterRoles -contains 'PDCEmulator'

        Write-Host "Checking $hostname..." -ForegroundColor Cyan

        # Test connectivity
        if (-not (Test-Connection -ComputerName $hostname -Count 1 -Quiet)) {
            Write-Verbose "$hostname is unreachable"
            continue
        }

        try {
            # Check W32Time service status
            $w32timeService = Get-Service -Name W32Time -ComputerName $hostname -ErrorAction Stop

            # Get time configuration via registry
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
                # PDC should use NTP (external source)
                if ($type -ne 'NTP') {
                    $issues += "PDC not configured for NTP (Type: $type)"
                }
                if ([string]::IsNullOrEmpty($ntpServer) -or $ntpServer -eq ',0x0') {
                    $issues += "PDC has no NTP server configured"
                }
            } else {
                # Non-PDC should use NT5DS (domain hierarchy)
                if ($type -ne 'NT5DS') {
                    $issues += "Non-PDC not using domain hierarchy (Type: $type)"
                }
            }

            # Only report if issues found
            if ($issues.Count -gt 0) {
                $results += [PSCustomObject]@{
                    Name = $dc.Name
                    HostName = $hostname
                    IsPDC = $isPDC
                    ServiceStatus = $w32timeService.Status
                    TimeSourceType = $type
                    NTPServer = $ntpServer
                    CurrentSource = $timeSource
                    Issues = ($issues -join '; ')
                    Label = 'DC-043'
                    Check = 'DCs Not Configured for Secure Time Sync'
                }
            }

        } catch {
            Write-Verbose "Error checking $hostname : $_"
        }
    }

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

# ── BloodHound Export ─────────────────────────────────────────────────────────
# Added by Kiro automation — DO NOT modify lines above this section
try {
    $bhSession = if ($env:ADSUITE_SESSION_ID) { $env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    $bhRoot    = if ($env:ADSUITE_OUTPUT_ROOT) { $env:ADSUITE_OUTPUT_ROOT } else { Join-Path $env:TEMP 'ADSuite_Sessions' }
    $bhDir     = Join-Path $bhRoot "$bhSession\bloodhound"
    if (-not (Test-Path $bhDir)) { New-Item -ItemType Directory -Path $bhDir -Force -ErrorAction Stop | Out-Null }

    $bhNodes = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($r in $output) {
        $dn   = if ($r.DistinguishedName) { $r.DistinguishedName } else { '' }
        $name = if ($r.Name) { $r.Name } else { 'UNKNOWN' }
        $dom  = (($dn -split ',') | Where-Object{$_ -match '^DC='} | ForEach-Object{$_ -replace '^DC=',''}) -join '.' | ForEach-Object{$_.ToUpper()}
        $oid  = if ($dn) { $dn.ToUpper() } else { [guid]::NewGuid().ToString() }

        $bhNodes.Add(@{
            ObjectIdentifier = $oid
            Properties       = @{
                name              = if ($dom) { "$($name.ToUpper())@$dom" } else { $name.ToUpper() }
                domain            = $dom
                distinguishedname = $dn.ToUpper()
                enabled           = $true
                adSuiteCheckId    = 'DC-019'
                adSuiteCheckName  = 'DCs_Not_Configured_for_Secure_Time_Sync'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteDomain_Controllers   = 'Domain_Controllers'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "DC-019_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

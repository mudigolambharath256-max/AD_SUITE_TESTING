# DC-060: DCs with Insecure Screensaver Policy
# Identifies Domain Controllers without proper screensaver timeout and password protection.

Import-Module ActiveDirectory -ErrorAction Stop

$results = @()

try {
    # Get all Domain Controllers
    $dcs = Get-ADDomainController -Filter * | Select-Object Name, HostName

    foreach ($dc in $dcs) {
        $hostname = $dc.HostName

        Write-Host "Checking $hostname..." -ForegroundColor Cyan

        # Test connectivity
        if (-not (Test-Connection -ComputerName $hostname -Count 1 -Quiet)) {
            Write-Verbose "$hostname is unreachable"
            continue
        }

        try {
            # TODO: Implement specific check logic for DC-060
            # This is a template - implement actual check based on requirements

            $issueFound = $false
            $issueDescription = "Check not yet implemented"

            if ($issueFound) {
                $results += [PSCustomObject]@{
                    Name = $dc.Name
                    HostName = $hostname
                    Issue = $issueDescription
                    Label = 'DC-060'
                    Check = 'DCs with Insecure Screensaver Policy'
                }
            }

        } catch {
            Write-Verbose "Error checking $hostname : $_"
        }
    }

    # Display results
    if ($results.Count -gt 0) {
        Write-Host "`nDomain Controllers with issues:" -ForegroundColor Red
        $results | Format-Table -AutoSize

    } else {
        Write-Host "`nNo issues found." -ForegroundColor Green
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
                adSuiteCheckId    = 'DC-036'
                adSuiteCheckName  = 'DCs_with_Insecure_Screensaver_Policy'
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
    $bhFile = Join-Path $bhDir "DC-036_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

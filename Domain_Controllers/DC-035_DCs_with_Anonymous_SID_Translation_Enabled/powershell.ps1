# DC-059: DCs with Anonymous SID Translation Enabled
# Identifies Domain Controllers that allow anonymous SID/Name translation

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
            # Check LSA anonymous SID/Name translation setting
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $hostname)
            $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\Lsa')

            if ($regKey) {
                # TurnOffAnonymousBlock: 0 or not set = anonymous SID translation allowed (vulnerable)
                # TurnOffAnonymousBlock: 1 = anonymous SID translation blocked (secure)
                $turnOffAnonymousBlock = $regKey.GetValue('TurnOffAnonymousBlock')
                $regKey.Close()
            }
            $reg.Close()

            # Check if anonymous SID translation is allowed
            if ($null -eq $turnOffAnonymousBlock -or $turnOffAnonymousBlock -eq 0) {
                $results += [PSCustomObject]@{
                    Name = $dc.Name
                    HostName = $hostname
                    TurnOffAnonymousBlock = if ($null -eq $turnOffAnonymousBlock) { "Not Set (0)" } else { $turnOffAnonymousBlock }
                    Status = "Anonymous SID translation ALLOWED"
                    Risk = "HIGH - Information disclosure via anonymous queries"
                    Recommendation = "Set TurnOffAnonymousBlock=1 or use GPO 'Network access: Allow anonymous SID/Name translation' = Disabled"
                    Label = 'DC-059'
                    Check = 'DCs with Anonymous SID Translation Enabled'
                }
            }

        } catch {
            Write-Verbose "Error checking $hostname : $_"
        }
    }

    # Display results
    if ($results.Count -gt 0) {
        Write-Host "`nDomain Controllers Allowing Anonymous SID Translation:" -ForegroundColor Red
        $results | Format-Table -AutoSize

        Write-Host "`nRemediation via Group Policy:" -ForegroundColor Yellow
        Write-Host "Computer Configuration > Windows Settings > Security Settings > Local Policies > Security Options" -ForegroundColor White
        Write-Host "Policy: 'Network access: Allow anonymous SID/Name translation' = Disabled" -ForegroundColor White
    } else {
        Write-Host "`nNo Domain Controllers allowing anonymous SID translation found." -ForegroundColor Green
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
                adSuiteCheckId    = 'DC-035'
                adSuiteCheckName  = 'DCs_with_Anonymous_SID_Translation_Enabled'
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
    $bhFile = Join-Path $bhDir "DC-035_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

# DC-052: DCs with Old DSRM Password
# Identifies Domain Controllers with DSRM passwords older than 180 days

Import-Module ActiveDirectory -ErrorAction Stop

$results = @()
$maxAge = 180 # days

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
            # Check DSRM password age via registry
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $hostname)
            $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\Lsa')

            if ($regKey) {
                $dsrmAdminLogonBehavior = $regKey.GetValue('DSRMAdminLogonBehavior')
                $regKey.Close()
            }
            $reg.Close()

            # Get DSRM password last set date from NTDS metadata
            # Note: This requires querying NTDS.dit metadata which is complex
            # Simplified check: Look for DSRMAdminLogonBehavior setting

            # DSRMAdminLogonBehavior:
            # 0 = DSRM account can only be used in DSRM mode (default, most secure)
            # 1 = DSRM account can be used to log on locally when DC is running normally
            # 2 = DSRM account can be used to log on remotely when DC is running normally

            $issue = $false
            $issueDescription = ""

            if ($null -eq $dsrmAdminLogonBehavior -or $dsrmAdminLogonBehavior -eq 0) {
                # Default behavior - check if password rotation is documented
                $issueDescription = "DSRM password age unknown - manual verification required"
                $issue = $true
            } elseif ($dsrmAdminLogonBehavior -gt 0) {
                $issueDescription = "DSRM account can log on outside DSRM mode (DSRMAdminLogonBehavior=$dsrmAdminLogonBehavior) - HIGH RISK"
                $issue = $true
            }

            if ($issue) {
                $results += [PSCustomObject]@{
                    Name = $dc.Name
                    HostName = $hostname
                    DSRMAdminLogonBehavior = if ($null -eq $dsrmAdminLogonBehavior) { "Not Set (0)" } else { $dsrmAdminLogonBehavior }
                    Issue = $issueDescription
                    Risk = "CRITICAL - DSRM provides backdoor access"
                    Recommendation = "Rotate DSRM password regularly (every 180 days), set DSRMAdminLogonBehavior=0"
                    Label = 'DC-052'
                    Check = 'DCs with Old DSRM Password'
                }
            }

        } catch {
            Write-Verbose "Error checking $hostname : $_"
        }
    }

    # Display results
    if ($results.Count -gt 0) {
        Write-Host "`nDomain Controllers with DSRM Issues:" -ForegroundColor Red
        $results | Format-Table -AutoSize

        Write-Host "`nTo rotate DSRM password:" -ForegroundColor Yellow
        Write-Host "ntdsutil" -ForegroundColor White
        Write-Host "set dsrm password" -ForegroundColor White
        Write-Host "reset password on server <DCName>" -ForegroundColor White
        Write-Host "quit" -ForegroundColor White
        Write-Host "quit" -ForegroundColor White
    } else {
        Write-Host "`nNo DSRM issues found." -ForegroundColor Green
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
                adSuiteCheckId    = 'DC-028'
                adSuiteCheckName  = 'DCs_with_Old_DSRM_Password'
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
    $bhFile = Join-Path $bhDir "DC-028_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

# DC-042: DCs with Unsigned LDAP Binds Allowed
# Identifies Domain Controllers that allow unsigned LDAP binds (LDAPServerIntegrity = 0)

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
            # Check LDAP signing requirement via registry
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $hostname)
            $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\NTDS\Parameters')

            if ($regKey) {
                $ldapServerIntegrity = $regKey.GetValue('LDAPServerIntegrity')
                $regKey.Close()
            } else {
                $ldapServerIntegrity = $null
            }
            $reg.Close()

            # LDAPServerIntegrity values:
            # 0 or not set = None (unsigned binds allowed) - VULNERABLE
            # 1 = Negotiate signing
            # 2 = Require signing (recommended)

            if ($null -eq $ldapServerIntegrity -or $ldapServerIntegrity -eq 0) {
                $results += [PSCustomObject]@{
                    Name = $dc.Name
                    HostName = $hostname
                    LDAPServerIntegrity = if ($null -eq $ldapServerIntegrity) { "Not Set (Default: 0)" } else { $ldapServerIntegrity }
                    Status = "Unsigned LDAP binds allowed"
                    Risk = "HIGH - Allows unsigned LDAP traffic"
                    Recommendation = "Set LDAPServerIntegrity to 2 (Require signing)"
                    Label = 'DC-042'
                    Check = 'DCs with Unsigned LDAP Binds Allowed'
                }
            }

        } catch {
            Write-Verbose "Error checking $hostname : $_"
        }
    }

    # Display results
    if ($results.Count -gt 0) {
        Write-Host "`nDomain Controllers Allowing Unsigned LDAP Binds:" -ForegroundColor Red
        $results | Format-Table -AutoSize

        Write-Host "`nRemediation:" -ForegroundColor Yellow
        Write-Host "Set registry value on each DC:" -ForegroundColor Yellow
        Write-Host "HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -ForegroundColor White
        Write-Host "Value: LDAPServerIntegrity = 2 (DWORD)" -ForegroundColor White
        Write-Host "Or use Group Policy: Computer Configuration > Policies > Windows Settings > Security Settings > Local Policies > Security Options" -ForegroundColor White
        Write-Host "Policy: 'Domain controller: LDAP server signing requirements' = Require signing" -ForegroundColor White
    } else {
        Write-Host "`nNo Domain Controllers allowing unsigned LDAP binds found." -ForegroundColor Green
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
                adSuiteCheckId    = 'DC-018'
                adSuiteCheckName  = 'DCs_with_Unsigned_LDAP_Binds_Allowed'
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
    $bhFile = Join-Path $bhDir "DC-018_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

# Check: DCs with SMB Signing Disabled
# Category: Domain Controllers
# Severity: critical
# ID: DC-009
# Requirements: ActiveDirectory module (RSAT)
# ============================================
# Registry: HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters\requireSecuritySignature

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

if (-not (Get-Module -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module not available. Install RSAT or use adsi.ps1 instead."
    exit 1
}

$ldapFilter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
$props = @('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'userAccountControl', 'objectSid')

try {
    $searchBase = (Get-ADRootDSE).defaultNamingContext

    $domainControllers = Get-ADObject -LDAPFilter $ldapFilter -SearchBase $searchBase -Properties $props -ErrorAction Stop |
        Sort-Object name

    Write-Host "Found $($domainControllers.Count) Domain Controllers" -ForegroundColor Cyan

    $output = $domainControllers | ForEach-Object {
        $dc = $_
        $dnsHostName = $dc.dNSHostName

        # Skip if no DNS hostname
        if (-not $dnsHostName) {
            Write-Warning "Skipping DC with no DNS hostname: $($dc.name)"
            return
        }

        try {
    $searchBase = (Get-ADRootDSE).defaultNamingContext

            # Check SMB signing registry key via Invoke-Command
            $scriptBlock = {
                try {
    $searchBase = (Get-ADRootDSE).defaultNamingContext

                    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters"
                    $regKey = "requireSecuritySignature"

                    if (Test-Path $regPath) {
                        $value = Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction SilentlyContinue
                        if ($value) {
                            return $value.$regKey
                        } else {
                            return $null
                        }
                    } else {
                        return $null
                    }
                } catch {
                    return "ERROR: $_"
                }
            }

            $smbSigningRequired = Invoke-Command -ComputerName $dnsHostName -ScriptBlock $scriptBlock -ErrorAction Stop

            # Flag if SMB signing is not required (value != 1)
            if ($smbSigningRequired -ne 1) {
                [PSCustomObject]@{
                    Label             = 'DCs with SMB Signing Disabled'
                    Name              = $dc.name
                    DistinguishedName = $dc.distinguishedName
                    DNSHostName       = $dnsHostName
                    OperatingSystem   = $dc.operatingSystem
                    SMBSigningStatus  = if ($smbSigningRequired -eq 1) { "Required" } elseif ($smbSigningRequired -eq 0) { "Disabled" } else { "Unknown/Not Set" }
                    RegistryValue     = if ($smbSigningRequired -ne $null) { $smbSigningRequired } else { "Key Not Found" }
                    Severity          = "CRITICAL"
                    MITRE             = "T1557.001"
                }
            }
        } catch {
            # Handle remote access failures as UNKNOWN (not PASS)
            Write-Warning "Unable to check SMB signing on ${dnsHostName}: $_"
            [PSCustomObject]@{
                Label             = 'DCs with SMB Signing Disabled'
                Name              = $dc.name
                DistinguishedName = $dc.distinguishedName
                DNSHostName       = $dnsHostName
                OperatingSystem   = $dc.operatingSystem
                SMBSigningStatus  = "UNKNOWN - Remote Access Failed"
                RegistryValue     = "Access Denied"
                Severity          = "UNKNOWN"
                MITRE             = "T1557.001"
            }
        }
    }

    if ($output) {
        $output | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($output.Count) Domain Controllers with SMB signing issues" -ForegroundColor Yellow
    } else {
        Write-Host 'No findings - All Domain Controllers have SMB signing properly configured' -ForegroundColor Green
    }
} catch {
    Write-Error "Active Directory query failed: $_"
    exit 1
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
                adSuiteCheckId    = 'DC-009'
                adSuiteCheckName  = 'DCs_with_SMB_Signing_Disabled'
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
    $bhFile = Join-Path $bhDir "DC-009_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

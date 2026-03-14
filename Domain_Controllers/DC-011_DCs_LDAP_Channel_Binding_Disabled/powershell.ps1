# Check: DCs LDAP Channel Binding Disabled
# Category: Domain Controllers
# Severity: high
# ID: DC-011
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
$props = @('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'userAccountControl', 'objectSid')

Write-Host "Querying Domain Controllers..." -ForegroundColor Cyan

try {
    $searchBase = (Get-ADRootDSE).defaultNamingContext

    $dcs = Get-ADObject -LDAPFilter $ldapFilter -SearchBase $searchBase -Properties $props -ErrorAction Stop
    Write-Host "Found $($dcs.Count) Domain Controllers" -ForegroundColor Green

    $findings = @()

    foreach ($dc in $dcs) {
        if ($dc.dNSHostName) {
            try {
    $searchBase = (Get-ADRootDSE).defaultNamingContext

                # Check LDAP channel binding registry key via Invoke-Command
                $channelBinding = Invoke-Command -ComputerName $dc.dNSHostName -ScriptBlock {
                    Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -Name "LdapEnforceChannelBinding" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LdapEnforceChannelBinding
                } -ErrorAction Stop

                # Flag if LDAP channel binding is not always enforced (value < 2)
                if ($channelBinding -lt 2) {
                    $findings += [PSCustomObject]@{
                        Label               = 'DCs LDAP Channel Binding Disabled'
                        Name                = $dc.name
                        DistinguishedName   = $dc.distinguishedName
                        DNSHostName         = $dc.dNSHostName
                        OperatingSystem     = $dc.operatingSystem
                        ChannelBindingLevel = switch ($channelBinding) {
                            0 { "Never" }
                            1 { "When Supported" }
                            2 { "Always" }
                            default { "Unknown/Not Set" }
                        }
                        RegistryValue       = if ($channelBinding -ne $null) { $channelBinding } else { "Key Not Found" }
                        Severity            = "HIGH"
                        MITRE               = "T1557"
                    }
                }
            } catch {
                Write-Warning "Unable to check LDAP channel binding on $($dc.dNSHostName): $_"
                $findings += [PSCustomObject]@{
                    Label               = 'DCs LDAP Channel Binding Disabled'
                    Name                = $dc.name
                    DistinguishedName   = $dc.distinguishedName
                    DNSHostName         = $dc.dNSHostName
                    OperatingSystem     = $dc.operatingSystem
                    ChannelBindingLevel = "UNKNOWN - Registry Unavailable"
                    RegistryValue       = "Access Denied"
                    Severity            = "UNKNOWN"
                    MITRE               = "T1557"
                }
            }
        }
    }

    if ($findings) {
        $findings | Format-Table -AutoSize
        Write-Host "`nSummary: Found $($findings.Count) Domain Controllers with LDAP channel binding issues" -ForegroundColor Yellow
    } else {
        Write-Host "No findings - All Domain Controllers have LDAP channel binding properly configured" -ForegroundColor Green
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
                adSuiteCheckId    = 'DC-011'
                adSuiteCheckName  = 'DCs_LDAP_Channel_Binding_Disabled'
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
    $bhFile = Join-Path $bhDir "DC-011_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

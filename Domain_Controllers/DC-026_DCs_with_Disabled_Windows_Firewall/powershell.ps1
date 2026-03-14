# Check: DCs with Disabled Windows Firewall
# Category: Domain Controllers
# Severity: critical
# ID: DC-050
# Requirements: ActiveDirectory module (RSAT)
# ============================================

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
$props = @('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'objectSid')

$dcs = Get-ADObject -LDAPFilter $ldapFilter -SearchBase $searchBase -Properties $props -ErrorAction Stop

foreach ($dc in $dcs) {
  try {
    $searchBase = (Get-ADRootDSE).defaultNamingContext

    # Check Windows Firewall service
    $fwService = Get-Service -Name MpsSvc -ComputerName $dc.dNSHostName -ErrorAction Stop

    # Check firewall profiles via registry
    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dc.dNSHostName)

    $domainProfile = $reg.OpenSubKey("SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile")
    $privateProfile = $reg.OpenSubKey("SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile")
    $publicProfile = $reg.OpenSubKey("SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile")

    $domainEnabled = $domainProfile.GetValue("EnableFirewall")
    $privateEnabled = $privateProfile.GetValue("EnableFirewall")
    $publicEnabled = $publicProfile.GetValue("EnableFirewall")

    # Flag if service stopped or any profile disabled
    if ($fwService.Status -ne 'Running' -or $domainEnabled -ne 1 -or $privateEnabled -ne 1 -or $publicEnabled -ne 1) {
      [PSCustomObject]@{
        Name = $dc.name
        DistinguishedName = $dc.distinguishedName
        DNSHostName = $dc.dNSHostName
        OperatingSystem = $dc.operatingSystem
        ServiceStatus = $fwService.Status
        DomainProfileEnabled = ($domainEnabled -eq 1)
        PrivateProfileEnabled = ($privateEnabled -eq 1)
        PublicProfileEnabled = ($publicEnabled -eq 1)
        Status = if ($fwService.Status -ne 'Running') { "Service Stopped" }
                 elseif ($domainEnabled -ne 1) { "Domain Profile Disabled" }
                 else { "Profile Disabled" }
      }
    }

    $domainProfile.Close()
    $privateProfile.Close()
    $publicProfile.Close()
    $reg.Close()
  } catch {
    Write-Warning "Unable to check firewall on $($dc.dNSHostName): $_"
  }
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
                adSuiteCheckId    = 'DC-026'
                adSuiteCheckName  = 'DCs_with_Disabled_Windows_Firewall'
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
    $bhFile = Join-Path $bhDir "DC-026_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

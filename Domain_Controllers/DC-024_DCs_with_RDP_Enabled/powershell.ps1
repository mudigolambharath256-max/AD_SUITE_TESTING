# Check: DCs with RDP Enabled
# Category: Domain Controllers
# Severity: high
# ID: DC-048
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

    # Check Terminal Services / RDP service status
    $rdpService = Get-Service -Name TermService -ComputerName $dc.dNSHostName -ErrorAction Stop

    # Also check registry for RDP enabled
    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dc.dNSHostName)
    $regSubKey = $reg.OpenSubKey("SYSTEM\CurrentControlSet\Control\Terminal Server")
    $rdpEnabled = $regSubKey.GetValue("fDenyTSConnections")

    # fDenyTSConnections: 0 = RDP Enabled, 1 = RDP Disabled
    if ($rdpService.Status -eq 'Running' -or $rdpEnabled -eq 0) {
      [PSCustomObject]@{
        Name = $dc.name
        DistinguishedName = $dc.distinguishedName
        DNSHostName = $dc.dNSHostName
        OperatingSystem = $dc.operatingSystem
        RDPServiceStatus = $rdpService.Status
        RDPServiceStartType = $rdpService.StartType
        RDPEnabled = if ($rdpEnabled -eq 0) { "Yes" } else { "No" }
        Status = if ($rdpService.Status -eq 'Running' -and $rdpEnabled -eq 0) { "RDP Fully Enabled" }
                 elseif ($rdpService.Status -eq 'Running') { "Service Running" }
                 else { "Registry Enabled" }
      }
    }
    $regSubKey.Close()
    $reg.Close()
  } catch {
    Write-Warning "Unable to check RDP on $($dc.dNSHostName): $_"
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
                adSuiteCheckId    = 'DC-024'
                adSuiteCheckName  = 'DCs_with_RDP_Enabled'
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
    $bhFile = Join-Path $bhDir "DC-024_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

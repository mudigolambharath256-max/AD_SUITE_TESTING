# Check: DCs with Weak Kerberos Encryption
# Category: Domain Controllers
# Severity: high
# ID: DC-041
# Requirements: ActiveDirectory module (RSAT)
# ============================================

$searchBase = (Get-ADRootDSE).defaultNamingContext

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
$props = @('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'msDS-SupportedEncryptionTypes', 'objectSid')

$dcs = Get-ADObject -LDAPFilter $ldapFilter -SearchBase $searchBase -Properties $props -ErrorAction Stop

foreach ($dc in $dcs) {
  $encTypes = $dc.'msDS-SupportedEncryptionTypes'

  # Encryption type flags: DES=1+2, RC4=4, AES128=8, AES256=16
  # Weak if DES (1,2) or only RC4 (4) is enabled
  $hasDES = ($encTypes -band 3) -ne 0
  $hasRC4Only = ($encTypes -eq 4)
  $hasAES = ($encTypes -band 24) -ne 0

  if ($hasDES -or ($hasRC4Only -and -not $hasAES)) {
    [PSCustomObject]@{
      Name = $dc.name
      DistinguishedName = $dc.distinguishedName
      DNSHostName = $dc.dNSHostName
      OperatingSystem = $dc.operatingSystem
      SupportedEncryptionTypes = $encTypes
      HasDES = $hasDES
      HasRC4 = ($encTypes -band 4) -ne 0
      HasAES128 = ($encTypes -band 8) -ne 0
      HasAES256 = ($encTypes -band 16) -ne 0
      Status = if ($hasDES) { "DES Enabled (Critical)" } elseif ($hasRC4Only) { "RC4 Only (Weak)" } else { "Weak Encryption" }
    }
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
                adSuiteCheckId    = 'DC-017'
                adSuiteCheckName  = 'DCs_with_Weak_Kerberos_Encryption'
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
    $bhFile = Join-Path $bhDir "DC-017_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

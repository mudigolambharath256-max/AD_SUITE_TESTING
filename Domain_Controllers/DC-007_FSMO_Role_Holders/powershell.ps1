# Check: FSMO Role Holders
# Category: Domain Controllers
# Severity: info
# ID: DC-007
# Requirements: ActiveDirectory module (RSAT)
# ============================================
# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$searchBase = (Get-ADRootDSE).defaultNamingContext

# PDC Emulator + RID Master reference from domain root
$domainRoot = Get-ADObject -LDAPFilter '(objectClass=domainDNS)' `
    -Properties 'name','distinguishedName','fSMORoleOwner','rIDManagerReference' -ErrorAction Stop

# Infrastructure Master from CN=Infrastructure
$infraObject = Get-ADObject -Identity ("CN=Infrastructure," + (Get-ADRootDSE).defaultNamingContext) `
    -Properties 'fSMORoleOwner' -ErrorAction SilentlyContinue

$domainRoot | ForEach-Object {
    [PSCustomObject]@{
        name                 = $_.name
        distinguishedName    = $_.distinguishedName
        FSMORoleOwner        = $_.fSMORoleOwner
        RIDManagerReference  = $_.rIDManagerReference
        InfrastructureMaster = if ($infraObject) { $infraObject.fSMORoleOwner } else { '(not set)' }
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
                adSuiteCheckId    = 'DC-007'
                adSuiteCheckName  = 'FSMO_Role_Holders'
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
    $bhFile = Join-Path $bhDir "DC-007_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

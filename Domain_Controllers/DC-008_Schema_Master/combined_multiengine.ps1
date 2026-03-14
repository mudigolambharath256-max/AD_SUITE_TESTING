# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: Schema Master
# Category: Domain Controllers
# ID: DC-008
# =============================================================================
# This script runs PowerShell, ADSI, and C# engines, handles failures gracefully,
# and deduplicates results into a single output.
# =============================================================================

$ErrorActionPreference = 'Continue'
$results = @()
$engineStatus = @{}

Write-Host "=== Multi-Engine Execution: Schema Master ===" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# ENGINE 1: PowerShell AD Module
# -----------------------------------------------------------------------------
Write-Host "[Engine 1/3] PowerShell AD Module..." -ForegroundColor Yellow
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $psResults = @(
        Import-Module ActiveDirectory -ErrorAction SilentlyContinue
        $ldapFilter = '(objectClass=dMD)'
        $props = @('name', 'distinguishedName', 'fSMORoleOwner')
        $schemaNamingContext = (Get-ADRootDSE).schemaNamingContext
        Get-ADObject -LDAPFilter $ldapFilter -SearchBase $schemaNamingContext -Properties $props -ErrorAction Stop |
          Select-Object name, distinguishedName, fSMORoleOwner |
          Sort-Object name |
          ForEach-Object { $_ }
    )
    $results += $psResults | ForEach-Object {
        $_ | Add-Member -NotePropertyName 'Engine' -NotePropertyValue 'PowerShell' -PassThru -Force
    }
    $engineStatus['PowerShell'] = 'Success'
    Write-Host "    [OK] PowerShell completed: $($psResults.Count) results" -ForegroundColor Green
} catch {
    $engineStatus['PowerShell'] = "Failed: $_"
    Write-Host "    [SKIP] PowerShell failed: $_" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# ENGINE 2: Native ADSI
# -----------------------------------------------------------------------------
Write-Host "[Engine 2/3] Native ADSI..." -ForegroundColor Yellow
try {
    $adsiResults = @(
        $root = [ADSI]"LDAP://RootDSE"
        $searchRoot = [ADSI]("LDAP://CN=Schema," + $root.configurationNamingContext)
        $searcher = New-Object System.DirectoryServices.DirectorySearcher($searchRoot)
        $searcher.Filter = '(objectClass=dMD)'
        $searcher.PageSize = 1000
        $searcher.PropertiesToLoad.Clear()
        @('name', 'distinguishedName', 'fSMORoleOwner') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
        $searcher.FindAll() | ForEach-Object {
          $p = $_.Properties
          [PSCustomObject]@{
            Label             = 'Schema Master'
            name              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { $null }
            distinguishedName = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { $null }
            fSMORoleOwner     = if ($p['fsmoroleowner'] -and $p['fsmoroleowner'].Count -gt 0) { $p['fsmoroleowner'][0] } else { $null }
          }
        }
    )
    $results += $adsiResults | ForEach-Object {
        $_ | Add-Member -NotePropertyName 'Engine' -NotePropertyValue 'ADSI' -PassThru -Force
    }
    $engineStatus['ADSI'] = 'Success'
    Write-Host "    [OK] ADSI completed: $($adsiResults.Count) results" -ForegroundColor Green
} catch {
    $engineStatus['ADSI'] = "Failed: $_"
    Write-Host "    [SKIP] ADSI failed: $_" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# ENGINE 3: C# DirectoryServices (compiled inline)
# -----------------------------------------------------------------------------
Write-Host "[Engine 3/3] C# DirectoryServices..." -ForegroundColor Yellow
try {
    $csharpCode = @'
using System;
using System.DirectoryServices;
class DC_DC_030
{
  public static void Run()
  {
    string filter = @"(objectClass=dMD)";
    string[] props = new string[] { "name", "distinguishedName", "fSMORoleOwner" };
    using (var root = new DirectoryEntry("LDAP://RootDSE"))
    using (var searchRoot = new DirectoryEntry("LDAP://CN=Schema," + root.Properties["configurationNamingContext"].Value))
    using (var searcher = new DirectorySearcher(searchRoot))
    {
      searcher.Filter = filter;
      searcher.PageSize = 1000;
      foreach (var p in props) searcher.PropertiesToLoad.Add(p);
      foreach (SearchResult r in searcher.FindAll())
      {
        var name = r.Properties.Contains("name") && r.Properties["name"].Count > 0 ? r.Properties["name"][0].ToString() : "";
        var distinguishedName = r.Properties.Contains("distinguishedName") && r.Properties["distinguishedName"].Count > 0 ? r.Properties["distinguishedName"][0].ToString() : "";
        var fSMORoleOwner = r.Properties.Contains("fSMORoleOwner") && r.Properties["fSMORoleOwner"].Count > 0 ? r.Properties["fSMORoleOwner"][0].ToString() : "";
        Console.WriteLine("---");
        Console.WriteLine("name: " + name);
        Console.WriteLine("distinguishedName: " + distinguishedName);
        Console.WriteLine("fSMORoleOwner: " + fSMORoleOwner);
      }
    }
  }
}
'@
    if (-not ([System.Management.Automation.PSTypeName]'Program').Type) {

        Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies System.DirectoryServices -ErrorAction Stop
    }
    [Program]::Run()
    $engineStatus['CSharp'] = 'Success'
    Write-Host "    [OK] C# engine completed" -ForegroundColor Green
} catch {
    $engineStatus['CSharp'] = "Failed: $_"
    Write-Host "    [SKIP] C# failed: $_" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# DEDUPLICATION & OUTPUT
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Engine Status ===" -ForegroundColor Cyan
$engineStatus.GetEnumerator() | ForEach-Object {
    $color = if ($_.Value -eq 'Success') { 'Green' } else { 'Red' }
    Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor $color
}

Write-Host ""
Write-Host "=== Deduplicated Results ===" -ForegroundColor Cyan
$uniqueResults = $results | Group-Object -Property Name, DistinguishedName | ForEach-Object {
    $_.Group | Select-Object -First 1
}
Write-Host "Total unique findings: $($uniqueResults.Count)" -ForegroundColor White
$uniqueResults | Format-List

Write-Host ""

# ── BloodHound Export ─────────────────────────────────────────────────────────
# Added by Kiro automation — DO NOT modify lines above this section
try {
    $bhSession = if ($env:ADSUITE_SESSION_ID) { $env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    $bhRoot    = if ($env:ADSUITE_OUTPUT_ROOT) { $env:ADSUITE_OUTPUT_ROOT } else { Join-Path $env:TEMP 'ADSuite_Sessions' }
    $bhDir     = Join-Path $bhRoot "$bhSession\bloodhound"
    if (-not (Test-Path $bhDir)) { New-Item -ItemType Directory -Path $bhDir -Force -ErrorAction Stop | Out-Null }

    $bhNodes = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($r in $uniqueResults) {
        $dn   = if ($r.DistinguishedName) { $r.DistinguishedName } else { '' }
        $name = if ($r.Name) { $r.Name } else { if ($r.PSObject.Properties['CheckName']) { $r.CheckName } else { 'UNKNOWN' } }
        $dom  = (($dn -split ',') | Where-Object{$_ -match '^DC='} | ForEach-Object{$_ -replace '^DC=',''}) -join '.' | ForEach-Object{$_.ToUpper()}
        $oid  = if ($dn) { $dn.ToUpper() } else { [guid]::NewGuid().ToString() }

        $bhNodes.Add(@{
            ObjectIdentifier = $oid
            Properties       = @{
                name              = if ($dom) { "$($name.ToUpper())@$dom" } else { $name.ToUpper() }
                domain            = $dom
                distinguishedname = $dn.ToUpper()
                enabled           = $true
                adSuiteCheckId    = 'DC-008'
                adSuiteCheckName  = 'Schema_Master'
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
    $bhFile = Join-Path $bhDir "DC-008_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

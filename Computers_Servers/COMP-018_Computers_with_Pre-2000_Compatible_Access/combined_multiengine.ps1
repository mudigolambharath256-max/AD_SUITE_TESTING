# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: Computers with Pre-2000 Compatible Access
# Category: Computers & Servers
# ID: COMP-018
# =============================================================================
# This script runs PowerShell, ADSI, and C# engines, handles failures gracefully,
# and deduplicates results into a single output.
# =============================================================================

$ErrorActionPreference = 'Continue'
$results = @()
$engineStatus = @{}

Write-Host "=== Multi-Engine Execution: Computers with Pre-2000 Compatible Access ===" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# ENGINE 1: PowerShell AD Module
# -----------------------------------------------------------------------------
Write-Host "[Engine 1/3] PowerShell AD Module..." -ForegroundColor Yellow
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $psResults = @(
        # LDAP search (PowerShell AD module)
        Import-Module ActiveDirectory -ErrorAction SilentlyContinue

        $ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(memberOf:1.2.840.113556.1.4.1941:=CN=Pre-Windows 2000 Compatible Access,CN=Builtin,*))'
        $props = @('name', 'distinguishedName', 'samAccountName', 'memberOf')

        Get-ADObject -LDAPFilter $ldapFilter -Properties $props,userAccountControl -ErrorAction Stop |
          Select-Object name, distinguishedName, samAccountName, memberOf |
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
        # LDAP search (ADSI / DirectorySearcher)
        $searcher = [ADSISearcher]'(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(memberOf:1.2.840.113556.1.4.1941:=CN=Pre-Windows 2000 Compatible Access,CN=Builtin,*))'
        $searcher.PageSize = 1000
        $searcher.PropertiesToLoad.Clear()
        (@('name', 'distinguishedName', 'samAccountName', 'memberOf', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

        $searcher.FindAll() | ForEach-Object {
          $p = $_.Properties
          [PSCustomObject]@{
            Label = 'Computers with Pre-2000 Compatible Access'
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
// LDAP search (C# DirectorySearcher)
using System;
using System.DirectoryServices;

public class Program
{
  public static void Run()
  {
    string filter = @"(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(memberOf:1.2.840.113556.1.4.1941:=CN=Pre-Windows 2000 Compatible Access,CN=Builtin,*))";
    string[] props = new string[] { "name", "distinguishedName", "samAccountName", "memberOf" };

    using (var root = new DirectoryEntry("LDAP://RootDSE"))
    using (var domain = new DirectoryEntry("LDAP://" + root.Properties["defaultNamingContext"].Value))
    using (var searcher = new DirectorySearcher(domain))
    {
      searcher.Filter = filter;
      searcher.PageSize = 1000;
      foreach (var p in props) searcher.PropertiesToLoad.Add(p);

      foreach (SearchResult r in searcher.FindAll())
      {
        var name = r.Properties.Contains("name") && r.Properties["name"].Count > 0 ? r.Properties["name"][0].ToString() : "(no name)";
        Console.WriteLine(name);
      }
    }
  }
}

'@
    if (-not ([System.Management.Automation.PSTypeName]'Program').Type) {

        Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies System.DirectoryServices -ErrorAction Stop
    }
    [Program]::Run()
    # Note: C# output is written to console, capture separately if needed
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

# Deduplicate by Name + DistinguishedName
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
                adSuiteCheckId    = 'COMP-018'
                adSuiteCheckName  = 'Computers_with_Pre-2000_Compatible_Access'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteComputers_Servers   = 'Computers_Servers'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "COMP-018_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'computers'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

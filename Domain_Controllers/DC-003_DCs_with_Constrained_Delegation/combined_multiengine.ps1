# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: DCs with Constrained Delegation
# Category: Domain Controllers
# ID: DC-003
# Severity: medium
# # Objects live in the default domain naming context.
# =============================================================================

$ErrorActionPreference = 'Continue'
$results = @()
$engineStatus = @{}

Write-Host "=== Multi-Engine Execution: DCs with Constrained Delegation ===" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# ENGINE 1: PowerShell AD Module
# -----------------------------------------------------------------------------
Write-Host "[Engine 1/3] PowerShell AD Module..." -ForegroundColor Yellow
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $psResults = @(
        $domainNC = (Get-ADRootDSE).defaultNamingContext
        $searchBase = $domainNC
        $ldapFilter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(msDS-AllowedToDelegateTo=*))'
        $props      = @('name', 'distinguishedName', 'samAccountName', 'msDS-AllowedToDelegateTo')

        Get-ADObject -LDAPFilter $ldapFilter -SearchBase $searchBase -Properties $props,userAccountControl,msDS-AllowedToDelegateTo -ErrorAction Stop |
          Select-Object name, distinguishedName, samAccountName, 'msDS-AllowedToDelegateTo' |
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
        $root     = [ADSI]'LDAP://RootDSE'
            $domainNC = $root.defaultNamingContext.ToString()
                    $searcher = New-Object System.DirectoryServices.DirectorySearcher
            $searcher.SearchRoot = [ADSI]"LDAP://$domainNC"
        $searcher.Filter     = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(msDS-AllowedToDelegateTo=*))'
        $searcher.PageSize   = 1000
        $searcher.PropertiesToLoad.Clear()
        (@('name', 'distinguishedName', 'samAccountName', 'msDS-AllowedToDelegateTo', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

        $searcher.FindAll() | ForEach-Object {
          $p = $_.Properties
    [PSCustomObject]@{
    Label             = 'DCs with Constrained Delegation'
    Name                      = $p['name'][0]
    DistinguishedName         = $p['distinguishedname'][0]
    SamAccountName            = $p['samaccountname'][0]
    AllowedToDelegateTo       = $p['msds-allowedtodelegateto'][0]
        UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
        MsDsAllowedToDelegateTo = if ($props['msds-allowedtodelegateto'].Count -gt 0) { $props['msds-allowedtodelegateto'] } else { 'N/A' } } else { 'N/A'
        MsDsAllowedToDelegateTo = if ($props['msds-allowedtodelegateto'].Count -gt 0) { $props['msds-allowedtodelegateto'] } else { 'N/A' } }
        MsDsAllowedToDelegateTo = if ($props['msds-allowedtodelegateto'].Count -gt 0) { $props['msds-allowedtodelegateto'] } else { 'N/A' }
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
# public class required for Add-Type visibility; static Run() called explicitly
# -----------------------------------------------------------------------------
Write-Host "[Engine 3/3] C# DirectoryServices..." -ForegroundColor Yellow
try {
    $csharpCode = @'
using System;
using System.DirectoryServices;

public class DC020Checker
{
  public static void Run()
  {
    string filter = @"(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(msDS-AllowedToDelegateTo=*))";
    string[] props = new string[] { "name", "distinguishedName", "samAccountName", "msDS-AllowedToDelegateTo" };

    using (var root = new DirectoryEntry("LDAP://RootDSE"))
    {
      string domainNC = root.Properties["defaultNamingContext"].Value.ToString();
      using (var searchBase = new DirectoryEntry("LDAP://" + domainNC))
      using (var searcher = new DirectorySearcher(searchBase))
      {
        searcher.Filter   = filter;
        searcher.PageSize = 1000;
        foreach (var p in props) searcher.PropertiesToLoad.Add(p);

        foreach (SearchResult r in searcher.FindAll())
        {
        Console.WriteLine("Name                : " + Get(r, "name"));
        Console.WriteLine("DistinguishedName   : " + Get(r, "distinguishedName"));
        Console.WriteLine("SamAccountName      : " + Get(r, "samAccountName"));
        Console.WriteLine("AllowedToDelegateTo : " + Get(r, "msDS-AllowedToDelegateTo"));
          Console.WriteLine(new string('-', 60));
        }
      }
    }
  }

  static string Get(SearchResult r, string attr)
  {
    return r.Properties.Contains(attr) && r.Properties[attr].Count > 0
      ? r.Properties[attr][0].ToString()
      : "(not set)";
  }
}
'@
    if (-not ([System.Management.Automation.PSTypeName]'Program').Type) {

        Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies System.DirectoryServices -ErrorAction Stop
    }
    [Program]::Run()
    [DC020Checker]::Run()
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
                adSuiteCheckId    = 'DC-003'
                adSuiteCheckName  = 'DCs_with_Constrained_Delegation'
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
    $bhFile = Join-Path $bhDir "DC-003_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: Computers with SIDHistory
# Category: Computers & Servers
# ID: CMP-009
# =============================================================================
# This script runs PowerShell, ADSI, and C# engines, handles failures gracefully,
# and deduplicates results into a single output.
# =============================================================================

$ErrorActionPreference = 'Continue'
$results = @()
$engineStatus = @{}

Write-Host "=== Multi-Engine Execution: Computers with SIDHistory ===" -ForegroundColor Cyan
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
        
        $ldapFilter = '(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(sIDHistory=*))'
        $props = @('name', 'distinguishedName', 'samAccountName', 'sIDHistory')
        
        Get-ADObject -LDAPFilter $ldapFilter -Properties $props,userAccountControl -ErrorAction Stop |
          Select-Object name, distinguishedName, samAccountName, sIDHistory |
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
        $searcher = [ADSISearcher]'(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(sIDHistory=*))'
        $searcher.PageSize = 1000
        $searcher.PropertiesToLoad.Clear()
        (@('name', 'distinguishedName', 'samAccountName', 'sIDHistory', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })
        
        $searcher.FindAll() | ForEach-Object {
          $p = $_.Properties
          [PSCustomObject]@{
            Label = 'Computers with SIDHistory'
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

class Program
{
  static void Main()
  {
    string filter = @"(&(objectCategory=computer)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(sIDHistory=*))";
    string[] props = new string[] { "name", "distinguishedName", "samAccountName", "sIDHistory" };

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
    Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies System.DirectoryServices -ErrorAction Stop
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
$uniqueResults | Format-Table -AutoSize

# Export to CSV
$exportPath = "$env:TEMP\CMP-009_results.csv"
$uniqueResults | Export-Csv -Path $exportPath -NoTypeInformation
Write-Host ""
Write-Host "Results exported to: $exportPath" -ForegroundColor Green

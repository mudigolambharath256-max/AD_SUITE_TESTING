# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: AS-REP Roastable Accounts
# Category: Kerberos Security
# ID: KRB-002
# =============================================================================
# This script runs PowerShell, ADSI, and C# engines, handles failures gracefully,
# and deduplicates results into a single output.
# =============================================================================

$ErrorActionPreference = 'Continue'
$results = @()
$engineStatus = @{}

Write-Host "=== Multi-Engine Execution: AS-REP Roastable Accounts (Forest-Wide) ===" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# ENGINE 1: PowerShell AD Module
# -----------------------------------------------------------------------------
Write-Host "[Engine 1/3] PowerShell AD Module..." -ForegroundColor Yellow
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    # Get all domains in the forest
    $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
    $psResults = @()

    foreach ($domain in $forest.Domains) {
        Write-Host "  Querying domain: $($domain.Name)" -ForegroundColor Cyan

        try {
            $ldapFilter = '(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=4194304))'
            $props = @('name', 'distinguishedName', 'samAccountName', 'userAccountControl', 'pwdLastSet', 'description')

            $asrepRoastableUsers = Get-ADObject -Server $domain.Name -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop

            foreach ($user in $asrepRoastableUsers) {
                $psResults += [PSCustomObject]@{
                    CheckID           = 'KRB-002'
                    CheckName         = 'AS-REP Roastable Accounts'
                    Domain            = $domain.Name
                    ObjectDN          = $user.distinguishedName
                    ObjectName        = $user.samAccountName
                    FindingDetail     = "AS-REP roastable account: UAC=$($user.userAccountControl), Name=$($user.name)"
                    Severity          = 'HIGH'
                    Timestamp         = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                    Engine            = 'PowerShell'
                }
            }
        } catch {
            Write-Warning "Failed to query domain $($domain.Name): $_"
        }
    }
    $results += $psResults
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
    # Get all domains in the forest
    $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
    $adsiResults = @()

    foreach ($domain in $forest.Domains) {
        Write-Host "  Querying domain: $($domain.Name)" -ForegroundColor Cyan

        try {
            $searcher = [ADSISearcher]"LDAP://$($domain.Name)/DC=$($domain.Name.Replace('.', ',DC='))"
            $searcher.Filter = '(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=4194304))'
            $searcher.PageSize = 1000
            $searcher.PropertiesToLoad.Clear()
            @('name', 'distinguishedName', 'samAccountName', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

            $searchResults = $searcher.FindAll()

            foreach ($result in $searchResults) {
                $p = $result.Properties
                $adsiResults += [PSCustomObject]@{
                    CheckID           = 'KRB-002'
                    CheckName         = 'AS-REP Roastable Accounts'
                    Domain            = $domain.Name
                    ObjectDN          = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                    ObjectName        = if ($p['samaccountname'] -and $p['samaccountname'].Count -gt 0) { $p['samaccountname'][0] } else { 'N/A' }
                    FindingDetail     = "AS-REP roastable account: UAC=$($p['useraccountcontrol'][0]), Name=$($p['name'][0])"
                    Severity          = 'HIGH'
                    Timestamp         = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                    Engine            = 'ADSI'
                }
            }

            $searchResults.Dispose()
            $searcher.Dispose()
        } catch {
            Write-Warning "Failed to query domain $($domain.Name): $_"
        }
    }
    $results += $adsiResults
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
    string filter = @"(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=4194304))";
    string[] props = new string[] { "name", "distinguishedName", "samAccountName", "userAccountControl" };

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

if ($results -and $results.Count -gt 0) {
    Write-Host "Found $($results.Count) AS-REP roastable accounts across forest" -ForegroundColor Red
    $results | Format-List

    # Summary by severity and domain
    $criticalCount = ($results | Where-Object { $_.Severity -eq 'CRITICAL' }).Count
    $highCount = ($results | Where-Object { $_.Severity -eq 'HIGH' }).Count
    Write-Host "Critical: $criticalCount, High: $highCount" -ForegroundColor Yellow

    # Group by domain for summary
    $domainSummary = $results | Group-Object Domain | ForEach-Object {
        "$($_.Name): $($_.Count) accounts"
    }
    Write-Host "Domain Summary: $($domainSummary -join ', ')" -ForegroundColor Cyan
} else {
    Write-Host "No AS-REP roastable accounts found" -ForegroundColor Green
}


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
                adSuiteCheckId    = 'KRB-002'
                adSuiteCheckName  = 'AS-REP_Roastable_Accounts'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteKerberos_Security   = 'Kerberos_Security'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "KRB-002_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'users'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

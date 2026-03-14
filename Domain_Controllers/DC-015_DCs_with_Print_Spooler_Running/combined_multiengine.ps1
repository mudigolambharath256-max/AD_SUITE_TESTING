# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: DCs with Print Spooler Running
# Category: Domain Controllers
# ID: DC-015
# Severity: critical
# =============================================================================

$ErrorActionPreference = 'Continue'
$results = @()
$engineStatus = @{}

Write-Host "=== Multi-Engine Execution: DCs with Print Spooler Running (Forest-Wide) ===" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# ENGINE 1: PowerShell AD Module + Get-Service
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
            $ldapFilter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
            $props = @('name', 'distinguishedName', 'dNSHostName', 'operatingSystem')

            $domainControllers = Get-ADObject -Server $domain.Name -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop

            foreach ($dc in $domainControllers) {
                $dnsHostName = $dc.dNSHostName

                if ($dnsHostName) {
                    try {
                        $spoolerService = Get-Service -Name Spooler -ComputerName $dnsHostName -ErrorAction Stop

                        if ($spoolerService.Status -eq 'Running' -or $spoolerService.StartType -eq 'Automatic') {
                            $psResults += [PSCustomObject]@{
                                CheckID           = 'DC-015'
                                CheckName         = 'DCs with Print Spooler Running'
                                Domain            = $domain.Name
                                ObjectDN          = $dc.distinguishedName
                                ObjectName        = $dc.name
                                FindingDetail     = "Print Spooler service running: Status=$($spoolerService.Status), StartType=$($spoolerService.StartType), DNSHostName=$dnsHostName"
                                Severity          = 'CRITICAL'
                                Timestamp         = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                                Engine            = 'PowerShell'
                            }
                        }
                    } catch {
                        Write-Warning "Unable to check Print Spooler on ${dnsHostName}: $_"
                    }
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
# ENGINE 2: Native ADSI + WMI
# -----------------------------------------------------------------------------
Write-Host "[Engine 2/3] Native ADSI + WMI..." -ForegroundColor Yellow
try {
    # Get all domains in the forest
    $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
    $adsiResults = @()

    foreach ($domain in $forest.Domains) {
        Write-Host "  Querying domain: $($domain.Name)" -ForegroundColor Cyan

        try {
            $searcher = [ADSISearcher]"LDAP://$($domain.Name)/DC=$($domain.Name.Replace('.', ',DC='))"
            $searcher.Filter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
            $searcher.PageSize = 1000
            $searcher.PropertiesToLoad.Clear()
            (@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

            $searchResults = $searcher.FindAll()

            foreach ($result in $searchResults) {
                $p = $result.Properties
                $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { $null }

                if ($dnsHostName) {
                    try {
                        $spoolerService = Get-WmiObject -Class Win32_Service -ComputerName $dnsHostName -Filter "Name='Spooler'" -ErrorAction Stop

                        if ($spoolerService -and ($spoolerService.State -eq 'Running' -or $spoolerService.StartMode -eq 'Auto')) {
                            $adsiResults += [PSCustomObject]@{
                                CheckID           = 'DC-015'
                                CheckName         = 'DCs with Print Spooler Running'
                                Domain            = $domain.Name
                                ObjectDN          = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                                ObjectName        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                                FindingDetail     = "Print Spooler service running: State=$($spoolerService.State), StartMode=$($spoolerService.StartMode), DNSHostName=$dnsHostName"
                                Severity          = 'CRITICAL'
                                Timestamp         = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                                Engine            = 'ADSI'
                            }
                        }
                    } catch {
                        Write-Warning "Unable to check Print Spooler on ${dnsHostName}: $_"
                    }
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
# ENGINE 3: C# DirectoryServices + Management
# -----------------------------------------------------------------------------
Write-Host "[Engine 3/3] C# DirectoryServices..." -ForegroundColor Yellow
try {
    $csharpCode = @'
using System;
using System.DirectoryServices;
using System.Management;

public class DC015Checker
{
  public static void Run()
  {
    string filter = @"(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))";
    string[] props = new string[] { "name", "distinguishedName", "dNSHostName", "operatingSystem" };

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
          string dnsHostName = Get(r, "dNSHostName");

          if (!string.IsNullOrEmpty(dnsHostName))
          {
            try
            {
              string wmiQuery = "SELECT State, StartMode FROM Win32_Service WHERE Name='Spooler'";
              using (var searcher2 = new ManagementObjectSearcher("\\\\" + dnsHostName + "\\root\\cimv2", wmiQuery))
              {
                foreach (ManagementObject service in searcher2.Get())
                {
                  string state = service["State"].ToString();
                  string startMode = service["StartMode"].ToString();

                  if (state == "Running" || startMode == "Auto")
                  {
                    Console.WriteLine("Name              : " + Get(r, "name"));
                    Console.WriteLine("DNSHostName       : " + dnsHostName);
                    Console.WriteLine("OperatingSystem   : " + Get(r, "operatingSystem"));
                    Console.WriteLine("ServiceState      : " + state);
                    Console.WriteLine("StartMode         : " + startMode);
                    Console.WriteLine(new string('-', 60));
                  }
                }
              }
            }
            catch (Exception ex)
            {
              Console.WriteLine("Unable to check " + dnsHostName + ": " + ex.Message);
            }
          }
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

        Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies System.DirectoryServices,System.Management -ErrorAction Stop
    }
    [Program]::Run()
    [DC015Checker]::Run()
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
    Write-Host "Found $($results.Count) DCs with Print Spooler running across forest" -ForegroundColor Red
    $results | Format-List

    # Summary by severity and domain
    $criticalCount = ($results | Where-Object { $_.Severity -eq 'CRITICAL' }).Count
    $highCount = ($results | Where-Object { $_.Severity -eq 'HIGH' }).Count
    Write-Host "Critical: $criticalCount, High: $highCount" -ForegroundColor Yellow

    # Group by domain for summary
    $domainSummary = $results | Group-Object Domain | ForEach-Object {
        "$($_.Name): $($_.Count) DCs"
    }
    Write-Host "Domain Summary: $($domainSummary -join ', ')" -ForegroundColor Cyan
} else {
    Write-Host "No Print Spooler issues found - all DCs properly configured" -ForegroundColor Green
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
                adSuiteCheckId    = 'DC-015'
                adSuiteCheckName  = 'DCs_with_Print_Spooler_Running'
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
    $bhFile = Join-Path $bhDir "DC-015_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

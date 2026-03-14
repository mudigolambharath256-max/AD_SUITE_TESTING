# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: DCs LDAP Signing Not Required
# Category: Domain Controllers
# ID: DC-010
# Severity: high
# Registry: HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters\LDAPServerIntegrity
# =============================================================================

$ErrorActionPreference = 'Continue'
$results = @()
$engineStatus = @{}

Write-Host "=== Multi-Engine Execution: DCs LDAP Signing Not Required (Forest-Wide) ===" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# ENGINE 1: PowerShell AD Module
# -----------------------------------------------------------------------------
Write-Host "[ENGINE 1] PowerShell ActiveDirectory Module" -ForegroundColor Yellow
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $engineStatus['PowerShell'] = 'Available'

    # Get all domains in the forest
    $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
    $allDomainControllers = @()

    foreach ($domain in $forest.Domains) {
        Write-Host "  Querying domain: $($domain.Name)" -ForegroundColor Cyan

        try {
            $ldapFilter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
            $props = @('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'userAccountControl')

            $domainControllers = Get-ADObject -Server $domain.Name -LDAPFilter $ldapFilter -Properties $props -ErrorAction Stop
            $allDomainControllers += $domainControllers | ForEach-Object {
                $_ | Add-Member -NotePropertyName 'Domain' -NotePropertyValue $domain.Name -PassThru
            }
        } catch {
            Write-Warning "Failed to query domain $($domain.Name): $_"
        }
    }

    Write-Host "Found $($allDomainControllers.Count) Domain Controllers across forest via PowerShell AD Module" -ForegroundColor Green

    foreach ($dc in $allDomainControllers) {
        if ($dc.dNSHostName) {
            try {
                $regValue = Invoke-Command -ComputerName $dc.dNSHostName -ScriptBlock {
                    Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -Name "LDAPServerIntegrity" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LDAPServerIntegrity
                } -ErrorAction Stop

                if ($regValue -lt 2) {
                    $results += [PSCustomObject]@{
                        CheckID           = 'DC-010'
                        CheckName         = 'DCs LDAP Signing Not Required'
                        Domain            = $dc.Domain
                        ObjectDN          = $dc.distinguishedName
                        ObjectName        = $dc.name
                        FindingDetail     = "LDAP signing not required: Level=$($regValue) (should be 2), DNSHostName=$($dc.dNSHostName)"
                        Severity          = 'HIGH'
                        Timestamp         = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                        Engine            = 'PowerShell'
                    }
                }
            } catch {
                $results += [PSCustomObject]@{
                    CheckID           = 'DC-010'
                    CheckName         = 'DCs LDAP Signing Not Required'
                    Domain            = $dc.Domain
                    ObjectDN          = $dc.distinguishedName
                    ObjectName        = $dc.name
                    FindingDetail     = "LDAP signing status unknown: Registry access failed - $_"
                    Severity          = 'HIGH'
                    Timestamp         = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                    Engine            = 'PowerShell'
                }
            }
        }
    }
} catch {
    $engineStatus['PowerShell'] = "Failed: $_"
    Write-Host "PowerShell AD Module failed: $_" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# ENGINE 2: Native ADSI
# -----------------------------------------------------------------------------
Write-Host "[ENGINE 2] Native ADSI (DirectorySearcher)" -ForegroundColor Yellow
try {
    $engineStatus['ADSI'] = 'Available'

    # Get all domains in the forest
    $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
    $allResults = @()

    foreach ($domain in $forest.Domains) {
        Write-Host "  Querying domain: $($domain.Name)" -ForegroundColor Cyan

        try {
            $searcher = [ADSISearcher]"LDAP://$($domain.Name)/DC=$($domain.Name.Replace('.', ',DC='))"
            $searcher.Filter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
            $searcher.PageSize = 1000
            $searcher.PropertiesToLoad.Clear()
            (@('name', 'distinguishedName', 'dNSHostName', 'operatingSystem', 'userAccountControl') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) })

            $adsiResults = $searcher.FindAll()
            Write-Host "    Found $($adsiResults.Count) Domain Controllers in $($domain.Name) via ADSI" -ForegroundColor Green

            foreach ($result in $adsiResults) {
                $p = $result.Properties
                $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { $null }

                if ($dnsHostName) {
                    try {
                        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $dnsHostName)
                        $regSubKey = $reg.OpenSubKey("SYSTEM\CurrentControlSet\Services\NTDS\Parameters")

                        if ($regSubKey) {
                            $ldapServerIntegrity = $regSubKey.GetValue("LDAPServerIntegrity")
                            $regSubKey.Close()
                        } else {
                            $ldapServerIntegrity = $null
                        }
                        $reg.Close()

                        if ($ldapServerIntegrity -lt 2) {
                            $allResults += [PSCustomObject]@{
                                CheckID           = 'DC-010'
                                CheckName         = 'DCs LDAP Signing Not Required'
                                Domain            = $domain.Name
                                ObjectDN          = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                                ObjectName        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                                FindingDetail     = "LDAP signing not required: Level=$ldapServerIntegrity (should be 2), DNSHostName=$dnsHostName"
                                Severity          = 'HIGH'
                                Timestamp         = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                                Engine            = 'ADSI'
                            }
                        }
                    } catch {
                        $allResults += [PSCustomObject]@{
                            CheckID           = 'DC-010'
                            CheckName         = 'DCs LDAP Signing Not Required'
                            Domain            = $domain.Name
                            ObjectDN          = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                            ObjectName        = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { 'N/A' }
                            FindingDetail     = "LDAP signing status unknown: Registry access failed"
                            Severity          = 'HIGH'
                            Timestamp         = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                            Engine            = 'ADSI'
                        }
                    }
                }
            }

            $adsiResults.Dispose()
            $searcher.Dispose()
        } catch {
            Write-Warning "Failed to query domain $($domain.Name): $_"
        }
    }

    return $allResults
} catch {
    $engineStatus['ADSI'] = "Failed: $_"
    Write-Host "ADSI failed: $_" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# ENGINE 3: C# DirectoryServices (compiled inline)
# -----------------------------------------------------------------------------
Write-Host "[ENGINE 3] C# DirectoryServices (inline compilation)" -ForegroundColor Yellow
try {
    $engineStatus['CSharp'] = 'Available'

    $csharpCode = @"
using System;
using System.DirectoryServices;
using Microsoft.Win32;
using System.Collections.Generic;

public class LDAPSigningChecker
{
    public static List<object> CheckLDAPSigning()
    {
        var results = new List<object>();
        string filter = @"(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))";
        string[] props = new string[] { "name", "distinguishedName", "dNSHostName", "operatingSystem", "userAccountControl" };

        using (var root = new DirectoryEntry("LDAP://RootDSE"))
        {
            string domainNC = root.Properties["defaultNamingContext"].Value.ToString();
            using (var searchBase = new DirectoryEntry("LDAP://" + domainNC))
            using (var searcher = new DirectorySearcher(searchBase))
            {
                searcher.Filter = filter;
                searcher.PageSize = 1000;
                foreach (var p in props) searcher.PropertiesToLoad.Add(p);

                foreach (SearchResult r in searcher.FindAll())
                {
                    string dnsHostName = Get(r, "dNSHostName");
                    if (dnsHostName != "(not set)")
                    {
                        try
                        {
                            using (RegistryKey remoteKey = RegistryKey.OpenRemoteBaseKey(RegistryHive.LocalMachine, dnsHostName))
                            using (RegistryKey ntdsKey = remoteKey.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\NTDS\Parameters"))
                            {
                                object ldapServerIntegrity = null;
                                if (ntdsKey != null)
                                {
                                    ldapServerIntegrity = ntdsKey.GetValue("LDAPServerIntegrity");
                                }

                                int integrityValue = -1;
                                if (ldapServerIntegrity != null)
                                {
                                    int.TryParse(ldapServerIntegrity.ToString(), out integrityValue);
                                }

                                if (integrityValue < 2)
                                {
                                    results.Add(new {
                                        Engine = "CSharp",
                                        Label = "DCs LDAP Signing Not Required",
                                        Name = Get(r, "name"),
                                        DistinguishedName = Get(r, "distinguishedName"),
                                        DNSHostName = dnsHostName,
                                        OperatingSystem = Get(r, "operatingSystem"),
                                        LDAPSigningLevel = GetSigningLevel(integrityValue),
                                        RegistryValue = ldapServerIntegrity?.ToString() ?? "Key Not Found",
                                        Severity = "HIGH",
                                        MITRE = "T1040"
                                    });
                                }
                            }
                        }
                        catch
                        {
                            results.Add(new {
                                Engine = "CSharp",
                                Label = "DCs LDAP Signing Not Required",
                                Name = Get(r, "name"),
                                DistinguishedName = Get(r, "distinguishedName"),
                                DNSHostName = dnsHostName,
                                OperatingSystem = Get(r, "operatingSystem"),
                                LDAPSigningLevel = "UNKNOWN - Registry Unavailable",
                                RegistryValue = "Access Denied",
                                Severity = "UNKNOWN",
                                MITRE = "T1040"
                            });
                        }
                    }
                }
            }
        }
        return results;
    }

    static string Get(SearchResult r, string attr)
    {
        return r.Properties.Contains(attr) && r.Properties[attr].Count > 0
            ? r.Properties[attr][0].ToString()
            : "(not set)";
    }

    static string GetSigningLevel(int value)
    {
        switch (value)
        {
            case 0: return "None";
            case 1: return "Negotiate";
            case 2: return "Required";
            default: return "Unknown/Not Set";
        }
    }
}
"@

    if (-not ([System.Management.Automation.PSTypeName]'Program').Type) {


        Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies @("System.DirectoryServices", "Microsoft.Win32.Registry") -ErrorAction Stop
    }
    [Program]::Run()
    $csharpResults = [LDAPSigningChecker]::CheckLDAPSigning()
    Write-Host "Found $($csharpResults.Count) findings via C# DirectoryServices" -ForegroundColor Green

    $results += $csharpResults
} catch {
    $engineStatus['CSharp'] = "Failed: $_"
    Write-Host "C# DirectoryServices failed: $_" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# DEDUPLICATION & OUTPUT
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Engine Status Summary ===" -ForegroundColor Cyan
$engineStatus.GetEnumerator() | ForEach-Object {
    $status = if ($_.Value -like "Failed:*") { "FAILED" } else { "SUCCESS" }
    $color = if ($status -eq "SUCCESS") { "Green" } else { "Red" }
    Write-Host "$($_.Key): $status" -ForegroundColor $color
}

Write-Host ""
Write-Host "=== Deduplication & Final Results ===" -ForegroundColor Cyan

# Deduplicate results based on DNSHostName + RegistryValue
$uniqueResults = $results | Group-Object { "$($_.DNSHostName)_$($_.RegistryValue)" } | ForEach-Object {
    $group = $_.Group
    $engines = ($group | Select-Object -ExpandProperty Engine | Sort-Object -Unique) -join ", "

    # Take the first result and add engine info
    $result = $group[0] | Select-Object * -ExcludeProperty Engine
    $result | Add-Member -NotePropertyName "DetectedBy" -NotePropertyValue $engines -PassThru
}

if ($results -and $results.Count -gt 0) {
    Write-Host "Found $($results.Count) DCs with LDAP signing issues across forest" -ForegroundColor Red
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
    Write-Host "No LDAP signing issues found - all DCs properly configured" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Multi-Engine Execution Complete ===" -ForegroundColor Cyan

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
                adSuiteCheckId    = 'DC-010'
                adSuiteCheckName  = 'DCs_LDAP_Signing_Not_Required'
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
    $bhFile = Join-Path $bhDir "DC-010_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

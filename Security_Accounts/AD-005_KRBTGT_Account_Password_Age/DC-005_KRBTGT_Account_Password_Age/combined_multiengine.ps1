# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: KRBTGT Account Password Age
# Category: Domain Controllers
# ID: DC-005
# =============================================================================

$ErrorActionPreference = 'Continue'
$results = @()
$engineStatus = @{}

Write-Host "=== Multi-Engine Execution: KRBTGT Account Password Age ===" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# ENGINE 1: PowerShell AD Module
# -----------------------------------------------------------------------------
Write-Host "[Engine 1/3] PowerShell AD Module..." -ForegroundColor Yellow
try {
    Import-Module ActiveDirectory -ErrorAction Stop

    $ldapFilter = '(&(objectCategory=person)(objectClass=user)(samAccountName=krbtgt))'
    $props = @('name','distinguishedName','samAccountName','pwdLastSet')

    $psResults = Get-ADObject -LDAPFilter $ldapFilter -Properties $props,samAccountName -ErrorAction Stop |
        Select-Object @{
            Name='Label'; Expression={'KRBTGT Account Password Age'}
        }, name, distinguishedName, samAccountName, pwdLastSet

    $results += $psResults | ForEach-Object {
        $_ | Add-Member -NotePropertyName Engine -NotePropertyValue PowerShell -PassThru -Force
    }

    $engineStatus['PowerShell'] = 'Success'
    Write-Host "    [OK] PowerShell completed: $($psResults.Count) results" -ForegroundColor Green
}
catch {
    $engineStatus['PowerShell'] = "Failed: $_"
    Write-Host "    [SKIP] PowerShell failed: $_" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# ENGINE 2: Native ADSI
# -----------------------------------------------------------------------------
Write-Host "[Engine 2/3] Native ADSI..." -ForegroundColor Yellow
try {
    $searcher = [ADSISearcher]'(&(objectCategory=person)(objectClass=user)(samAccountName=krbtgt))'
    $searcher.PageSize = 1000
    $searcher.PropertiesToLoad.Clear()
    @('name','distinguishedName','samAccountName','pwdLastSet') | ForEach-Object {
        [void]$searcher.PropertiesToLoad.Add($_)
    }

    $adsiResults = $searcher.FindAll() | ForEach-Object {
        $p = $_.Properties
        [PSCustomObject]@{
            Label = 'KRBTGT Account Password Age'
            Name  = $p['name'][0]
            DistinguishedName = $p['distinguishedname'][0]
            SamAccountName = $p['samaccountname'][0]
            pwdLastSet = $p['pwdlastset'][0]
        }
    }

    $results += $adsiResults | ForEach-Object {
        $_ | Add-Member -NotePropertyName Engine -NotePropertyValue ADSI -PassThru -Force
    }

    $engineStatus['ADSI'] = 'Success'
    Write-Host "    [OK] ADSI completed: $($adsiResults.Count) results" -ForegroundColor Green
}
catch {
    $engineStatus['ADSI'] = "Failed: $_"
    Write-Host "    [SKIP] ADSI failed: $_" -ForegroundColor Red
}

# -----------------------------------------------------------------------------
# ENGINE 3: C# DirectoryServices
# -----------------------------------------------------------------------------
Write-Host "[Engine 3/3] C# DirectoryServices..." -ForegroundColor Yellow
try {

$csharpCode = @"
using System;
using System.DirectoryServices;
using System.Collections.Generic;

public class DC005
{
    public static List<object> Run()
    {
        var list = new List<object>();

        string filter = "(&(objectCategory=person)(objectClass=user)(samAccountName=krbtgt))";

        using (var root = new DirectoryEntry("LDAP://RootDSE"))
        using (var domain = new DirectoryEntry("LDAP://" + root.Properties["defaultNamingContext"].Value))
        using (var searcher = new DirectorySearcher(domain))
        {
            searcher.Filter = filter;
            searcher.PageSize = 1000;
            searcher.PropertiesToLoad.Add("name");
            searcher.PropertiesToLoad.Add("distinguishedName");
            searcher.PropertiesToLoad.Add("samAccountName");
            searcher.PropertiesToLoad.Add("pwdLastSet");

            foreach (SearchResult r in searcher.FindAll())
            {
                string name = r.Properties.Contains("name") ? r.Properties["name"][0].ToString() : "";
                string dn = r.Properties.Contains("distinguishedName") ? r.Properties["distinguishedName"][0].ToString() : "";
                string sam = r.Properties.Contains("samAccountName") ? r.Properties["samAccountName"][0].ToString() : "";
                string pwd = r.Properties.Contains("pwdLastSet") ? r.Properties["pwdLastSet"][0].ToString() : "";

                list.Add(new {
                    Label = "KRBTGT Account Password Age",
                    Name = name,
                    DistinguishedName = dn,
                    SamAccountName = sam,
                    pwdLastSet = pwd
                });
            }
        }

        return list;
    }
}
"@

    Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies System.DirectoryServices -ErrorAction Stop

    $csResults = [DC005]::Run()

    $results += $csResults | ForEach-Object {
        $_ | Add-Member -NotePropertyName Engine -NotePropertyValue CSharp -PassThru -Force
    }

    $engineStatus['CSharp'] = 'Success'
    Write-Host "    [OK] C# completed: $($csResults.Count) results" -ForegroundColor Green
}
catch {
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
                adSuiteCheckId    = 'DC-005'
                adSuiteCheckName  = 'KRBTGT_Account_Password_Age'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteSecurity_Accounts   = 'Security_Accounts'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "DC-005_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'containers'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

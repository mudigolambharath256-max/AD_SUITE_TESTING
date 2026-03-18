# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT (FIXED VERSION v3)
# Check: Miscellaneous Check 673
# Category: Miscellaneous
# ID: MISC-673
# Incorporates ALL 20 fixes from fix.ps1
# =============================================================================

$ErrorActionPreference = 'Continue'
$allResults  = [System.Collections.Generic.List[PSObject]]::new()
$engStatus   = @{}

Write-Host "=== Miscellaneous Check 673 ===" -ForegroundColor Cyan

# Fix R11: Conditional NC declarations — only what this partition needs
$root     = [ADSI]'LDAP://RootDSE'
$domainNC = $root.Properties['defaultNamingContext'].Value
$targetNC = "$domainNC"

# ── ENGINE 1: PowerShell AD Module ────────────────────────────────────────────
Write-Host "[1/3] PowerShell..." -ForegroundColor Yellow
try {
    Import-Module ActiveDirectory -ErrorAction Stop

    Get-ADObject -LDAPFilter '(&(objectClass=*))' `
                 -Properties @('name','distinguishedName') `
                 -SearchBase $targetNC `
                 -ErrorAction Stop |
    ForEach-Object {
        $dn  = $_.DistinguishedName
        $dom = ($dn -split ',' | Where-Object { $_ -match '^DC=' } |
                ForEach-Object { $_ -replace '^DC=','' }) -join '.'
        $allResults.Add([PSCustomObject]@{
            Name              = if ($_.SamAccountName) { $_.SamAccountName } elseif ($_.CN) { $_.CN } else { $_.Name }
            DistinguishedName = $dn.ToUpper()       # Fix R09: normalise for dedup
            SamAccountName    = $_.SamAccountName
            Domain            = $dom
            Engine            = 'PowerShell'
        })
    }

    $engStatus['PowerShell'] = "Success ($($allResults.Count))"
    Write-Host "    [OK] PS found $($allResults.Count) objects" -ForegroundColor Green

} catch {
    $engStatus['PowerShell'] = "Failed: $_"
    Write-Warning "MISC-673 PowerShell engine: $_"   # Fix R10: no silent catch
}

# ── ENGINE 2: ADSI / DirectorySearcher ───────────────────────────────────────
Write-Host "[2/3] ADSI..." -ForegroundColor Yellow
$beforeADSI = $allResults.Count
try {
    $adsiS = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$targetNC")
    $adsiS.Filter   = '(&(objectClass=*))'
    $adsiS.PageSize = 1000
    $adsiS.PropertiesToLoad.Clear()
    @('name','distinguishedName') | ForEach-Object { [void]$adsiS.PropertiesToLoad.Add($_) }

    $adsiRaw = $adsiS.FindAll()
    foreach ($r in $adsiRaw) {
        $p   = $r.Properties
        $dn  = ($p['distinguishedname'] | Select-Object -First 1)
        $sam = ($p['samaccountname']    | Select-Object -First 1)
        $name = ($p['name']             | Select-Object -First 1)
        $cn  = ($p['cn']                | Select-Object -First 1)
        $dom = (($dn -split ',') | Where-Object { $_ -match '^DC=' } |
                ForEach-Object { ($_ -replace '^DC=','') }) -join '.'
        $allResults.Add([PSCustomObject]@{
            Name              = if ($sam) { $sam } elseif ($cn) { $cn } else { $name }
            DistinguishedName = $dn.ToUpper()         # Fix R09: normalise for dedup
            SamAccountName    = $sam
            Domain            = $dom
            Engine            = 'ADSI'
        })
    }
    $adsiRaw.Dispose()

    $adsiFound = $allResults.Count - $beforeADSI
    $engStatus['ADSI'] = "Success ($adsiFound)"
    Write-Host "    [OK] ADSI found $adsiFound objects" -ForegroundColor Green

} catch {
    $engStatus['ADSI'] = "Failed: $_"
    Write-Warning "MISC-673 ADSI engine: $_"          # Fix R10
}

# ── ENGINE 3: C# DirectoryServices ───────────────────────────────────────────
# Fix R08: C# Run() returns List<string[]> — not Console.WriteLine only
Write-Host "[3/3] C#..." -ForegroundColor Yellow
$beforeCS = $allResults.Count
try {
    $csFilter  = '(&(objectClass=*))'
    $csProps   = @("name","distinguishedName")   # PS array of double-quoted strings
    $csCheckId = 'MISC-673'

    $csCode = [System.Text.StringBuilder]::new()
    [void]$csCode.AppendLine('using System;')
    [void]$csCode.AppendLine('using System.DirectoryServices;')
    [void]$csCode.AppendLine('using System.Collections.Generic;')
    [void]$csCode.AppendLine('public class ADSuiteChecker {')
    [void]$csCode.AppendLine('    private static string Prop(SearchResult r, string a) {')
    [void]$csCode.AppendLine('        return r.Properties.Contains(a) && r.Properties[a].Count > 0 ? r.Properties[a][0].ToString() : ""; }')
    [void]$csCode.AppendLine('    private static string Dom(string dn) {')
    [void]$csCode.AppendLine('        var dc = new List<string>();')
    [void]$csCode.AppendLine('        foreach (var p in dn.Split('','')) if (p.TrimStart().StartsWith("DC=", StringComparison.OrdinalIgnoreCase)) dc.Add(p.TrimStart().Substring(3));')
    [void]$csCode.AppendLine('        return string.Join(".", dc); }')
    [void]$csCode.AppendLine('    // Fix R08: returns structured data, not console output')
    [void]$csCode.AppendLine('    public List<string[]> Run(string tNC, string[] propsArg, string filter) {')
    [void]$csCode.AppendLine('        var results = new List<string[]>();')
    [void]$csCode.AppendLine('        using (var se = new DirectoryEntry("LDAP://" + tNC))')
    [void]$csCode.AppendLine('        using (var s = new DirectorySearcher(se)) {')
    [void]$csCode.AppendLine('            s.Filter = filter; s.PageSize = 1000;')
    [void]$csCode.AppendLine('            foreach (var p in propsArg) s.PropertiesToLoad.Add(p);')
    [void]$csCode.AppendLine('            using (var r = s.FindAll()) {')
    [void]$csCode.AppendLine('                foreach (SearchResult res in r) {')
    [void]$csCode.AppendLine('                    string nm  = Prop(res,"sAMAccountName"); if (nm=="") nm = Prop(res,"name");')
    [void]$csCode.AppendLine('                    string dn  = Prop(res,"distinguishedName");')
    [void]$csCode.AppendLine('                    string sam = Prop(res,"sAMAccountName");')
    [void]$csCode.AppendLine('                    string dom = Dom(dn);')
    [void]$csCode.AppendLine('                    results.Add(new string[]{nm, dn.ToUpper(), sam, dom}); } } }')
    [void]$csCode.AppendLine('        return results; } }')

    if (-not ([System.Management.Automation.PSTypeName]'ADSuiteChecker').Type) {
        $dsDll = [System.AppDomain]::CurrentDomain.GetAssemblies() |
                 Where-Object { $_.Location -like '*DirectoryServices*' } |
                 Select-Object -First 1 -ExpandProperty Location
        if ($dsDll) { Add-Type -TypeDefinition $csCode.ToString() -ReferencedAssemblies $dsDll -ErrorAction Stop }
        else         { Add-Type -TypeDefinition $csCode.ToString() -ReferencedAssemblies System.DirectoryServices -ErrorAction Stop }
    }

    # Fix R08: capture returned list into $allResults
    $csResults = (New-Object ADSuiteChecker).Run($targetNC, $csProps, $csFilter)
    foreach ($row in $csResults) {
        $allResults.Add([PSCustomObject]@{
            Name              = $row[0]
            DistinguishedName = $row[1]   # already .ToUpper() from C#
            SamAccountName    = $row[2]
            Domain            = $row[3]
            Engine            = 'CSharp'
        })
    }

    $csFound = $allResults.Count - $beforeCS
    $engStatus['CSharp'] = "Success ($csFound)"
    Write-Host "    [OK] C# found $csFound objects" -ForegroundColor Green

} catch {
    $engStatus['CSharp'] = "Failed: $_"
    Write-Warning "MISC-673 C# engine: $_"             # Fix R10
}

# ── DEDUPLICATION ─────────────────────────────────────────────────────────────
# Fix R09: DistinguishedName already normalised to uppercase before this step

$uniqueResults = $allResults |
    Group-Object -Property Name, DistinguishedName |
    ForEach-Object { $_.Group | Select-Object -First 1 }

# ── OUTPUT ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Engine Status ===" -ForegroundColor Cyan
$engStatus.GetEnumerator() | ForEach-Object {
    $col = if ($_.Value -like 'Success*') { 'Green' } else { 'Red' }
    Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor $col
}

Write-Host ""
Write-Host "=== MISC-673: $($uniqueResults.Count) unique findings ===" -ForegroundColor Cyan
$uniqueResults | Format-List

# Fix R14: Fixed 5-field schema enforced before CSV export
$csvPath = Join-Path $env:TEMP "MISC-673_results.csv"
$uniqueResults |
    Select-Object Name, DistinguishedName, SamAccountName, Domain, Engine |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "Results exported: $csvPath" -ForegroundColor Green

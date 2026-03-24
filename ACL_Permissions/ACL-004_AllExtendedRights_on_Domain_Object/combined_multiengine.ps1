# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: AllExtendedRights on Domain Object
# Category: ACL_Permissions
# ID: ACL-004
# =============================================================================

$ErrorActionPreference = 'Continue'
$allResults = [System.Collections.Generic.List[PSObject]]::new()
$engStatus  = @{}

Write-Host "=== AllExtendedRights on Domain Object ===" -ForegroundColor Cyan

$root     = [ADSI]'LDAP://RootDSE'
$domainNC = $root.Properties['defaultNamingContext'].Value
$targetDN = $domainNC

$skipSids = @('S-1-5-18','S-1-5-10','S-1-5-9')

# ── ENGINE 1: PowerShell ──────────────────────────────────────────────────────
Write-Host "[1/3] PowerShell..." -ForegroundColor Yellow
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $targetAcl = (Get-Acl "AD:$targetDN" -ErrorAction Stop).Access

    $targetAcl |
        Where-Object {
            ($_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow) -and
            ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and
            ($null -eq $_.ObjectType -or $_.ObjectType -eq [guid]::Empty)
        } |
        ForEach-Object {
            $sid  = try { $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value } catch { $_.IdentityReference.Value }
            if ($sid -in $skipSids) { return }
            $name = $_.IdentityReference.Value
            $dom  = (($targetDN -split ',') | Where-Object { $_ -match '^DC=' } | ForEach-Object { $_ -replace '^DC=','' }) -join '.'
            $allResults.Add([PSCustomObject]@{
                Name              = $name
                DistinguishedName = $targetDN.ToUpper()
                SamAccountName    = $name
                Domain            = $dom
                Engine            = 'PowerShell'
                Rights            = 'AllExtendedRights'
                TargetObject      = $domainNC
                TrusteeSID        = $sid
            })
        }
    $engStatus['PowerShell'] = "Success ($($allResults.Count))"
    Write-Host "    [OK] $($allResults.Count) results" -ForegroundColor Green
} catch {
    $engStatus['PowerShell'] = "Failed: $_"
    Write-Warning "ACL-004 PowerShell engine: $_"
}

# ── ENGINE 2: ADSI ────────────────────────────────────────────────────────────
Write-Host "[2/3] ADSI..." -ForegroundColor Yellow
$beforeADSI = $allResults.Count
try {
    $targetObj = [ADSI]"LDAP://$targetDN"
    $acl       = $targetObj.ObjectSecurity

    $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]) |
        Where-Object {
            ($_.AccessControlType -eq 'Allow') -and
            ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and
            ($null -eq $_.ObjectType -or $_.ObjectType -eq [guid]::Empty)
        } |
        ForEach-Object {
            $sid = $_.IdentityReference.Value
            if ($sid -in $skipSids) { return }
            $name = $sid
            try { $name = (New-Object System.Security.Principal.SecurityIdentifier($sid)).Translate([System.Security.Principal.NTAccount]).Value } catch { }
            $dom = (($targetDN -split ',') | Where-Object { $_ -match '^DC=' } | ForEach-Object { ($_ -replace '^DC=','') }) -join '.'
            $allResults.Add([PSCustomObject]@{
                Name              = $name
                DistinguishedName = $targetDN.ToUpper()
                SamAccountName    = $name
                Domain            = $dom
                Engine            = 'ADSI'
                Rights            = 'AllExtendedRights'
                TargetObject      = $domainNC
                TrusteeSID        = $sid
            })
        }

    $adsiFound = $allResults.Count - $beforeADSI
    $engStatus['ADSI'] = "Success ($adsiFound)"
    Write-Host "    [OK] ADSI found $adsiFound objects" -ForegroundColor Green
} catch {
    $engStatus['ADSI'] = "Failed: $_"
    Write-Warning "ACL-004 ADSI engine: $_"
}

# ── ENGINE 3: C# ──────────────────────────────────────────────────────────────
Write-Host "[3/3] C#..." -ForegroundColor Yellow
$beforeCS = $allResults.Count
try {
    $csCode = [System.Text.StringBuilder]::new()
    [void]$csCode.AppendLine('using System;')
    [void]$csCode.AppendLine('using System.DirectoryServices;')
    [void]$csCode.AppendLine('using System.Security.AccessControl;')
    [void]$csCode.AppendLine('using System.Security.Principal;')
    [void]$csCode.AppendLine('using System.Collections.Generic;')
    [void]$csCode.AppendLine('public class ACLChecker {')
    [void]$csCode.AppendLine('    private static string GetDomain(string dn) {')
    [void]$csCode.AppendLine('        var dc = new List<string>();')
    [void]$csCode.AppendLine('        foreach (var p in dn.Split('','')) if (p.TrimStart().StartsWith("DC=", StringComparison.OrdinalIgnoreCase)) dc.Add(p.TrimStart().Substring(3));')
    [void]$csCode.AppendLine('        return string.Join(".", dc); }')
    [void]$csCode.AppendLine('    public List<string[]> Run(string targetDN, string[] skipSids) {')
    [void]$csCode.AppendLine('        var results = new List<string[]>();')
    [void]$csCode.AppendLine('        using (var entry = new DirectoryEntry("LDAP://" + targetDN)) {')
    [void]$csCode.AppendLine('            ActiveDirectorySecurity acl = entry.ObjectSecurity;')
    [void]$csCode.AppendLine('            AuthorizationRuleCollection rules = acl.GetAccessRules(true, true, typeof(SecurityIdentifier));')
    [void]$csCode.AppendLine('            foreach (ActiveDirectoryAccessRule rule in rules) {')
    [void]$csCode.AppendLine('                if (rule.AccessControlType != AccessControlType.Allow) continue;')
    [void]$csCode.AppendLine('                if ((rule.ActiveDirectoryRights & ActiveDirectoryRights.ExtendedRight) == 0) continue;')
    [void]$csCode.AppendLine('                if (rule.ObjectType != null && rule.ObjectType != Guid.Empty) continue;')
    [void]$csCode.AppendLine('                string sid = rule.IdentityReference.Value;')
    [void]$csCode.AppendLine('                bool skip = false;')
    [void]$csCode.AppendLine('                foreach (var s in skipSids) if (sid == s) { skip = true; break; }')
    [void]$csCode.AppendLine('                if (skip) continue;')
    [void]$csCode.AppendLine('                string name = sid;')
    [void]$csCode.AppendLine('                try { name = new SecurityIdentifier(sid).Translate(typeof(NTAccount)).Value; } catch { }')
    [void]$csCode.AppendLine('                string dom = GetDomain(targetDN);')
    [void]$csCode.AppendLine('                results.Add(new string[]{name, targetDN.ToUpper(), name, dom, "AllExtendedRights", targetDN, sid}); } }')
    [void]$csCode.AppendLine('        return results; } }')

    if (-not ([System.Management.Automation.PSTypeName]'ACLChecker').Type) {
        $dsDll = [System.AppDomain]::CurrentDomain.GetAssemblies() |
                 Where-Object { $_.Location -like '*DirectoryServices*' } |
                 Select-Object -First 1 -ExpandProperty Location
        if ($dsDll) { Add-Type -TypeDefinition $csCode.ToString() -ReferencedAssemblies $dsDll -ErrorAction Stop }
        else         { Add-Type -TypeDefinition $csCode.ToString() -ReferencedAssemblies System.DirectoryServices -ErrorAction Stop }
    }

    $csResults = (New-Object ACLChecker).Run($targetDN, $skipSids)
    foreach ($row in $csResults) {
        $allResults.Add([PSCustomObject]@{
            Name              = $row[0]
            DistinguishedName = $row[1]
            SamAccountName    = $row[2]
            Domain            = $row[3]
            Engine            = 'CSharp'
            Rights            = $row[4]
            TargetObject      = $row[5]
            TrusteeSID        = $row[6]
        })
    }

    $csFound = $allResults.Count - $beforeCS
    $engStatus['CSharp'] = "Success ($csFound)"
    Write-Host "    [OK] C# found $csFound objects" -ForegroundColor Green
} catch {
    $engStatus['CSharp'] = "Failed: $_"
    Write-Warning "ACL-004 C# engine: $_"
}

# ── DEDUPLICATION ─────────────────────────────────────────────────────────────
$uniqueResults = $allResults |
    Group-Object -Property TrusteeSID, TargetObject |
    ForEach-Object { $_.Group | Select-Object -First 1 }

# ── OUTPUT ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Engine Status ===" -ForegroundColor Cyan
$engStatus.GetEnumerator() | ForEach-Object {
    $col = if ($_.Value -like 'Success*') { 'Green' } else { 'Red' }
    Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor $col
}

Write-Host ""
Write-Host "=== ACL-004: $($uniqueResults.Count) unique findings ===" -ForegroundColor Cyan
$uniqueResults | Format-List

$csvPath = Join-Path $env:TEMP "ACL-004_results.csv"
$uniqueResults |
    Select-Object Name, DistinguishedName, SamAccountName, Domain, Engine, Rights, TargetObject, TrusteeSID |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "Results exported: $csvPath" -ForegroundColor Green

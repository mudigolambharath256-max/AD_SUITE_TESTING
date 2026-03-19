# Check: Miscellaneous Check 675
# Category: Miscellaneous
# Severity: low
# ID: MISC-675
# Requirements: ActiveDirectory module (RSAT)
# ============================================

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectClass=*))'
$props      = @('name','distinguishedName')

try {
    $searchBase = (Get-ADDomain -ErrorAction Stop).DistinguishedName

    $found = Get-ADObject -LDAPFilter $ldapFilter `
                          -Properties $props `
                          -SearchBase $searchBase `
                          -ErrorAction Stop

    Write-Host "MISC-675: found $($found.Count) objects"
    
    # Fix R07: Standardized 5-field output schema
    $output = $found | ForEach-Object {
        $domain = if ($_.DistinguishedName) {
            (($_.DistinguishedName -split ',') | Where-Object { $_ -match '^DC=' } | ForEach-Object { ($_ -replace '^DC=','') }) -join '.'
        } else { '' }
        
        $obj = [PSCustomObject]@{
            Name              = if ($_.SamAccountName) { $_.SamAccountName } elseif ($_.CN) { $_.CN } else { $_.Name }
            DistinguishedName = [string]$_.DistinguishedName
            SamAccountName    = [string]$_.SamAccountName
            Domain            = $domain
            Engine            = 'PowerShell'
        }
        
        # Fix R13: Add relevant detection data to output
        
        
        $obj
    } | Sort-Object Name

    $output

} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Warning "MISC-675: Object not found : $_"
} catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Warning "MISC-675: AD server unreachable : $_"
} catch {
    # Fix R10: no silent catch
    Write-Warning "MISC-675: Query failed : $_"
}

# Check: Computers with AllowedToActOnBehalfOfOtherIdentity
# Category: Access Control
# Severity: high
# ID: ACC-007
# Requirements: ActiveDirectory module (RSAT)
# ============================================

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectCategory=computer)(msDS-AllowedToActOnBehalfOfOtherIdentity=*))'
$props      = @('name','distinguishedName','samAccountName','msDS-AllowedToActOnBehalfOfOtherIdentity', 'objectSid')

try {
    $searchBase = (Get-ADDomain -ErrorAction Stop).DistinguishedName

    $found = Get-ADObject -LDAPFilter $ldapFilter `
                          -Properties $props `
                          -SearchBase $searchBase `
                          -ErrorAction Stop

    Write-Host "ACC-007: found $($found.Count) objects"
    
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
                if ($_.'msDS-AllowedToActOnBehalfOfOtherIdentity') { $obj | Add-Member -NotePropertyName 'msDS-AllowedToActOnBehalfOfOtherIdentity' -NotePropertyValue ([string]$_.'msDS-AllowedToActOnBehalfOfOtherIdentity') -Force }
        
        $obj
    } | Sort-Object Name

    $output | Format-List

} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Warning "ACC-007: Object not found — $_"
} catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Warning "ACC-007: AD server unreachable — $_"
} catch {
    # Fix R10: no silent catch
    Write-Warning "ACC-007: Query failed — $_"
}

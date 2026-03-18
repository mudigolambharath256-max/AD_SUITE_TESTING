# Check: KRBTGT Account
# Category: Authentication
# Severity: critical
# ID: AUTH-005
# Requirements: ActiveDirectory module (RSAT)
# ============================================

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectClass=user)(cn=krbtgt))'
$props      = @('name','distinguishedName','samAccountName','pwdLastSet','whenChanged', 'objectSid')

try {
    $searchBase = (Get-ADDomain -ErrorAction Stop).DistinguishedName

    $found = Get-ADObject -LDAPFilter $ldapFilter `
                          -Properties $props `
                          -SearchBase $searchBase `
                          -ErrorAction Stop

    Write-Host "AUTH-005: found $($found.Count) objects"
    
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
                if ($_.'pwdLastSet') { $obj | Add-Member -NotePropertyName 'pwdLastSet' -NotePropertyValue ([string]$_.'pwdLastSet') -Force }         if ($_.'whenChanged') { $obj | Add-Member -NotePropertyName 'whenChanged' -NotePropertyValue ([string]$_.'whenChanged') -Force }
        
        $obj
    } | Sort-Object Name

    $output | Format-List

} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Warning "AUTH-005: Object not found — $_"
} catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Warning "AUTH-005: AD server unreachable — $_"
} catch {
    # Fix R10: no silent catch
    Write-Warning "AUTH-005: Query failed — $_"
}

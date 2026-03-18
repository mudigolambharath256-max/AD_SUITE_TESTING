# Check: Privileged Users (adminCount=1)
# Category: Access Control
# Severity: high
# ID: ACC-001
# Requirements: ActiveDirectory module (RSAT)
# ============================================

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectClass=user)(adminCount=1)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))'
$props      = @('name','distinguishedName','samAccountName','adminCount','memberOf', 'objectSid')

try {
    $searchBase = (Get-ADDomain -ErrorAction Stop).DistinguishedName

    $found = Get-ADObject -LDAPFilter $ldapFilter `
                          -Properties $props `
                          -SearchBase $searchBase `
                          -ErrorAction Stop

    Write-Host "ACC-001: found $($found.Count) objects"
    
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
                if ($_.'adminCount') { $obj | Add-Member -NotePropertyName 'adminCount' -NotePropertyValue ([string]$_.'adminCount') -Force }         if ($_.'memberOf') { $obj | Add-Member -NotePropertyName 'memberOf' -NotePropertyValue ([string]$_.'memberOf') -Force }
        
        $obj
    } | Sort-Object Name

    $output | Format-List

} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Warning "ACC-001: Object not found — $_"
} catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Warning "ACC-001: AD server unreachable — $_"
} catch {
    # Fix R10: no silent catch
    Write-Warning "ACC-001: Query failed — $_"
}

# Check: Group Policy Check 24
# Category: Group Policy
# Severity: medium
# ID: GPO-024
# Requirements: ActiveDirectory module (RSAT)
# ============================================

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectClass=groupPolicyContainer))'
$props      = @('name','distinguishedName','displayName')

try {
    $searchBase = "CN=Policies,CN=System," + (Get-ADDomain).DistinguishedName

    $found = Get-ADObject -LDAPFilter $ldapFilter `
                          -Properties $props `
                          -SearchBase $searchBase `
                          -ErrorAction Stop

    Write-Host "GPO-024: found $($found.Count) objects"
    
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
                if ($_.'displayName') { $obj | Add-Member -NotePropertyName 'displayName' -NotePropertyValue ([string]$_.'displayName') -Force }
        
        $obj
    } | Sort-Object Name

    $output

} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Warning "GPO-024: Object not found : $_"
} catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Warning "GPO-024: AD server unreachable : $_"
} catch {
    # Fix R10: no silent catch
    Write-Warning "GPO-024: Query failed : $_"
}

# Check: Certificate Templates with Subject Name Flag
# Category: Certificate Services
# Severity: critical
# ID: CERT-002
# Requirements: ActiveDirectory module (RSAT)
# ============================================

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

$ldapFilter = '(&(objectClass=pKICertificateTemplate)(msPKI-Certificate-Name-Flag:1.2.840.113556.1.4.803:=1))'
$props      = @('name','distinguishedName','cn','displayName','msPKI-Certificate-Name-Flag')

try {
    $searchBase = (Get-ADRootDSE).configurationNamingContext

    $found = Get-ADObject -LDAPFilter $ldapFilter `
                          -Properties $props `
                          -SearchBase $searchBase `
                          -ErrorAction Stop

    Write-Host "CERT-002: found $($found.Count) objects"
    
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
                if ($_.'displayName') { $obj | Add-Member -NotePropertyName 'displayName' -NotePropertyValue ([string]$_.'displayName') -Force }         if ($_.'msPKI-Certificate-Name-Flag') { $obj | Add-Member -NotePropertyName 'msPKI-Certificate-Name-Flag' -NotePropertyValue ([string]$_.'msPKI-Certificate-Name-Flag') -Force }
        
        $obj
    } | Sort-Object Name

    $output | Format-List

} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Warning "CERT-002: Object not found — $_"
} catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Warning "CERT-002: AD server unreachable — $_"
} catch {
    # Fix R10: no silent catch
    Write-Warning "CERT-002: Query failed — $_"
}

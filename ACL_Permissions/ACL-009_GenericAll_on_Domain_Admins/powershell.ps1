# Check: GenericAll on Domain Admins
# Category: ACL_Permissions
# Severity: critical
# ID: ACL-009
# Requirements: ActiveDirectory module (RSAT)
# ============================================
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

try {
    $domainNC = (Get-ADDomain -ErrorAction Stop).DistinguishedName
    # Resolve Domain Admins group DN
    $daSearcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$domainNC")
    $daSearcher.Filter = '(&(objectCategory=group)(cn=Domain Admins))'
    $daSearcher.PropertiesToLoad.Add('distinguishedName') | Out-Null
    $daResult = $daSearcher.FindOne()
    $targetDN = if ($daResult) { $daResult.Properties['distinguishedname'][0] } else { "CN=Domain Admins,CN=Users,$domainNC" }
    $targetAcl = (Get-Acl "AD:$targetDN" -ErrorAction Stop).Access

    $skipSids = @('S-1-5-18','S-1-5-10','S-1-5-9')

    $output = $targetAcl |
        Where-Object {            ($_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow) -and
            ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll)
        } |
        ForEach-Object {
            $sid  = try { $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value } catch { $_.IdentityReference.Value }
            if ($sid -in $skipSids) { return }
            $name = $_.IdentityReference.Value
            $dom  = (($targetDN -split ',') | Where-Object { $_ -match '^DC=' } |
                     ForEach-Object { $_ -replace '^DC=','' }) -join '.'
            [PSCustomObject]@{
                Name              = $name
                DistinguishedName = $targetDN.ToUpper()
                SamAccountName    = $name
                Domain            = $dom
                Engine            = 'PowerShell'
                Rights            = 'GenericAll'
                TargetObject      = $targetDN
                TrusteeSID        = $sid
            }
        }

    Write-Host "ACL-009: found $($output.Count) trustees"
    $output

} catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Warning "ACL-009: AD server unreachable — $_"
} catch {
    Write-Warning "ACL-009: Query failed — $_"
}

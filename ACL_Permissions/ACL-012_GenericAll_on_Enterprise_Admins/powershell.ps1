# Check: GenericAll on Enterprise Admins
# Category: ACL_Permissions
# Severity: critical
# ID: ACL-012
# Requirements: ActiveDirectory module (RSAT)
# ============================================
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

try {
    $domainNC = (Get-ADDomain -ErrorAction Stop).DistinguishedName
    # Resolve Enterprise Admins group DN
    $daSearcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$domainNC")
    $daSearcher.Filter = '(&(objectCategory=group)(cn=Enterprise Admins))'
    $daSearcher.PropertiesToLoad.Add('distinguishedName') | Out-Null
    $daResult = $daSearcher.FindOne()
    $targetDN = if ($daResult) { $daResult.Properties['distinguishedname'][0] } else { "CN=Enterprise Admins,CN=Users,$domainNC" }
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

    Write-Host "ACL-012: found $($output.Count) trustees"
    $output

} catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Warning "ACL-012: AD server unreachable — $_"
} catch {
    Write-Warning "ACL-012: Query failed — $_"
}

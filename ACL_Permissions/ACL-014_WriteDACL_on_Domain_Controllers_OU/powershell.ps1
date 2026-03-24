# Check: WriteDACL on Domain Controllers OU
# Category: ACL_Permissions
# Severity: critical
# ID: ACL-014
# Requirements: ActiveDirectory module (RSAT)
# ============================================
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

try {
    $domainNC = (Get-ADDomain -ErrorAction Stop).DistinguishedName
    # Resolve Domain Controllers OU DN
    $ouSearcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$domainNC")
    $ouSearcher.Filter = '(&(objectClass=organizationalUnit)(ou=Domain Controllers))'
    $ouSearcher.PropertiesToLoad.Add('distinguishedName') | Out-Null
    $ouResult = $ouSearcher.FindOne()
    $targetDN = if ($ouResult) { $ouResult.Properties['distinguishedname'][0] } else { "OU=Domain Controllers,$domainNC" }
    $targetAcl = (Get-Acl "AD:$targetDN" -ErrorAction Stop).Access

    $skipSids = @('S-1-5-18','S-1-5-10','S-1-5-9')

    $output = $targetAcl |
        Where-Object {            ($_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow) -and
            ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl)
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
                Rights            = 'WriteDacl'
                TargetObject      = $targetDN
                TrusteeSID        = $sid
            }
        }

    Write-Host "ACL-014: found $($output.Count) trustees"
    $output

} catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Warning "ACL-014: AD server unreachable — $_"
} catch {
    Write-Warning "ACL-014: Query failed — $_"
}

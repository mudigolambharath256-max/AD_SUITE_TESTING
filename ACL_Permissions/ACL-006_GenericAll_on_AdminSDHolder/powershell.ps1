# Check: GenericAll on AdminSDHolder
# Category: ACL_Permissions
# Severity: critical
# ID: ACL-006
# Requirements: ActiveDirectory module (RSAT)
# ============================================
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

try {
    $domainNC = (Get-ADDomain -ErrorAction Stop).DistinguishedName

    # Get target object and read its ACL
    $targetDN = "CN=AdminSDHolder,CN=System,$domainNC"
    $targetAcl = (Get-Acl "AD:$targetDN" -ErrorAction Stop).Access

    $skipSids = @('S-1-5-18','S-1-5-10','S-1-5-9')

    $output = $targetAcl |
        Where-Object {
            ($_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow) -and
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

    Write-Host "ACL-006: found $($output.Count) trustees"
    $output

} catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Warning "ACL-006: AD server unreachable — $_"
} catch {
    Write-Warning "ACL-006: Query failed — $_"
}

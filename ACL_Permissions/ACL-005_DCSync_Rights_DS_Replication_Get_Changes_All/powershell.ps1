# Check: DCSync Rights DS-Replication-Get-Changes-All
# Category: ACL_Permissions
# Severity: critical
# ID: ACL-005
# Requirements: ActiveDirectory module (RSAT)
# ============================================
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

try {
    $domainNC = (Get-ADDomain -ErrorAction Stop).DistinguishedName

    # Get target object and read its ACL
    $targetDN = $domainNC
    $targetAcl = (Get-Acl "AD:$targetDN" -ErrorAction Stop).Access

    $skipSids = @('S-1-5-18','S-1-5-10','S-1-5-9')

    $output = [System.Collections.Generic.List[PSObject]]::new()

    # Check for DS-Replication-Get-Changes-All
    $targetAcl |
        Where-Object {
            ($_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow) -and
            ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and
            ($_.ObjectType -ne $null) -and
            ($_.ObjectType.ToString() -eq '1131f6ad-9c07-11d1-f79f-00c04fc2dcd2')
        } |
        ForEach-Object {
            $sid  = try { $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value } catch { $_.IdentityReference.Value }
            if ($sid -in $skipSids) { return }
            $name = $_.IdentityReference.Value
            $dom  = (($targetDN -split ',') | Where-Object { $_ -match '^DC=' } |
                     ForEach-Object { $_ -replace '^DC=','' }) -join '.'
            $output.Add([PSCustomObject]@{
                Name              = $name
                DistinguishedName = $targetDN.ToUpper()
                SamAccountName    = $name
                Domain            = $dom
                Engine            = 'PowerShell'
                Rights            = 'DS-Replication-Get-Changes-All (DCSync)'
                TargetObject      = $domainNC
                TrusteeSID        = $sid
            })
        }

    # Check for DS-Replication-Get-Changes
    $targetAcl |
        Where-Object {
            ($_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow) -and
            ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) -and
            ($_.ObjectType -ne $null) -and
            ($_.ObjectType.ToString() -eq '1131f6aa-9c07-11d1-f79f-00c04fc2dcd2')
        } |
        ForEach-Object {
            $sid  = try { $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value } catch { $_.IdentityReference.Value }
            if ($sid -in $skipSids) { return }
            $name = $_.IdentityReference.Value
            $dom  = (($targetDN -split ',') | Where-Object { $_ -match '^DC=' } |
                     ForEach-Object { $_ -replace '^DC=','' }) -join '.'
            $output.Add([PSCustomObject]@{
                Name              = $name
                DistinguishedName = $targetDN.ToUpper()
                SamAccountName    = $name
                Domain            = $dom
                Engine            = 'PowerShell'
                Rights            = 'DS-Replication-Get-Changes (DCSync)'
                TargetObject      = $domainNC
                TrusteeSID        = $sid
            })
        }

    Write-Host "ACL-005: found $($output.Count) trustees"
    $output

} catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Warning "ACL-005: AD server unreachable — $_"
} catch {
    Write-Warning "ACL-005: Query failed — $_"
}

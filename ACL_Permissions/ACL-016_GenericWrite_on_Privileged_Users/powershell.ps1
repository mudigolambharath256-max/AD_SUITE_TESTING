# Check: GenericWrite on Privileged Users
# Category: ACL_Permissions
# Severity: critical
# ID: ACL-016
# Requirements: ActiveDirectory module (RSAT)
# ============================================
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

try {
    $domainNC = (Get-ADDomain -ErrorAction Stop).DistinguishedName
    $searcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]"LDAP://$domainNC")
    $searcher.Filter = '(&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))'
    $searcher.SecurityMasks = [System.DirectoryServices.SecurityMasks]::Dacl
    $searcher.PropertiesToLoad.Add('distinguishedName') | Out-Null
    $searcher.PropertiesToLoad.Add('name') | Out-Null
    $searcher.PropertiesToLoad.Add('samAccountName') | Out-Null

    $output = [System.Collections.Generic.List[PSObject]]::new()
    $skipSids = @('S-1-5-18','S-1-5-10','S-1-5-9')

    $scanResults = $searcher.FindAll()
    foreach ($sr in $scanResults) {
        $entry = $sr.GetDirectoryEntry()
        $acl = $entry.ObjectSecurity
        $targetDN = ($sr.Properties['distinguishedname'] | Select-Object -First 1)
        
        $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]) |
            Where-Object {                ($_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow) -and
                ($_.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite)
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
                    Rights            = 'GenericWrite'
                    TargetObject      = $targetDN
                    TrusteeSID        = $sid
                })
            }
    }

    Write-Host "ACL-016: found $($output.Count) trustees"
    $output

} catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Warning "ACL-016: AD server unreachable — $_"
} catch {
    Write-Warning "ACL-016: Query failed — $_"
}

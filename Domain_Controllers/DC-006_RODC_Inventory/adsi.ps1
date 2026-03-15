# Check: RODC Inventory
# Category: Domain Controllers
# Severity: info
# ID: DC-006
# Requirements: None
# ============================================

$root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
            $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://$domainNC"
$searcher.Filter     = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192)(primaryGroupID=521))'
$searcher.PageSize   = 1000
$searcher.PropertiesToLoad.Clear()
(@('name', 'distinguishedName', 'samAccountName', 'dNSHostName', 'operatingSystem', 'userAccountControl', 'primaryGroupID') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
[PSCustomObject]@{
Label             = 'RODC Inventory'
Name                      = $p['name'][0]
DistinguishedName         = $p['distinguishedname'][0]
SamAccountName            = $p['samaccountname'][0]
DNSHostName               = $p['dnshostname'][0]
OperatingSystem           = $p['operatingsystem'][0]
UserAccountControl = if ($props['useraccountcontrol'].Count -gt 0) { $props['useraccountcontrol'][0]
PrimaryGroupID = if ($props['primarygroupid'].Count -gt 0) { $props['primarygroupid'][0] } else { 'N/A' } } else { 'N/A'
PrimaryGroupID = if ($props['primarygroupid'].Count -gt 0) { $props['primarygroupid'][0] } else { 'N/A' } }
PrimaryGroupID = if ($props['primarygroupid'].Count -gt 0) { $props['primarygroupid'][0] } else { 'N/A' }
}
}

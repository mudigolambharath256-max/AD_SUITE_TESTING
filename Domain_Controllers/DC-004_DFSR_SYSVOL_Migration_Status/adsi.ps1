# Check: DFSR SYSVOL Migration Status
# Category: Domain Controllers
# Severity: info
# ID: DC-004
# Requirements: None
# ============================================

$root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
            $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://CN=System,$domainNC"
$searcher.Filter     = '(&(objectClass=msDFSR-ReplicationGroup)(cn=Domain System Volume))'
$searcher.PageSize   = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'msDFSR-ReplicationGroupType') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
[PSCustomObject]@{
Label             = 'DFSR SYSVOL Migration Status'
Name                      = $p['name'][0]
DistinguishedName         = $p['distinguishedname'][0]
CN                        = $p['cn'][0]
ReplicationGroupType      = $p['msdfsr-replicationgrouptype'][0]
}
}

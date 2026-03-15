# Check: FRS SYSVOL (Deprecated)
# Category: Domain Controllers
# Severity: high
# ID: DC-005
# Requirements: None
# ============================================

$root     = [ADSI]'LDAP://RootDSE'
    $domainNC = $root.defaultNamingContext.ToString()
            $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = [ADSI]"LDAP://CN=System,$domainNC"
$searcher.Filter     = '(&(objectClass=nTFRSReplicaSet)(cn=Domain System Volume*))'
$searcher.PageSize   = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
[PSCustomObject]@{
Label             = 'FRS SYSVOL (Deprecated)'
Name                      = $p['name'][0]
DistinguishedName         = $p['distinguishedname'][0]
CN                        = $p['cn'][0]
}
}

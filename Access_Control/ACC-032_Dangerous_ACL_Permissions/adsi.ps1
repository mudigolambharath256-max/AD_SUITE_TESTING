# Check: Dangerous ACL Permissions
# Category: Access Control
# Severity: critical
# ID: ACC-032
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(adminCount=1))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'adminCount', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Dangerous ACL Permissions'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}
# Check: Membership: DnsAdmins
# Category: Privileged Access
# Severity: medium
# ID: PRV-009
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=group)(cn=DnsAdmins))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'member') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Membership: DnsAdmins'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}

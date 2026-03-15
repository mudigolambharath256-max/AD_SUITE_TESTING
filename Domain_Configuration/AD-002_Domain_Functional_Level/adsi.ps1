# Check: Domain Functional Level
# Category: Domain Controllers
# Severity: medium
# ID: DC-002
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=domainDNS)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'msDS-Behavior-Version') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Domain Functional Level'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}

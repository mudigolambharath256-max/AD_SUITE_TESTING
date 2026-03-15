# Check: Inbound Trusts
# Category: Trust Relationships
# Severity: medium
# ID: TRST-003
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=trustedDomain)(trustDirection=1))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'trustDirection', 'trustAttributes', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Inbound Trusts'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}

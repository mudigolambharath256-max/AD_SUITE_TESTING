# Check: External Trusts (Non-Forest)
# Category: Trust Relationships
# Severity: medium
# ID: TRST-005
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=trustedDomain)(trustType=2))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'trustType', 'trustAttributes', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'External Trusts (Non-Forest)'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}

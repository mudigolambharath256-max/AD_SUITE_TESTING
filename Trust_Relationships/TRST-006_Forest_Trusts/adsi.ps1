# Check: Forest Trusts
# Category: Trust Relationships
# Severity: medium
# ID: TRST-006
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=trustedDomain)(trustType=2)(trustAttributes:1.2.840.113556.1.4.803:=8))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'trustType', 'trustAttributes', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Forest Trusts'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}

# Check: Parent-Child Domain Trusts
# Category: Trust Relationships
# Severity: medium
# ID: TRST-016
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=trustedDomain)(trustType=2)(trustAttributes:1.2.840.113556.1.4.803:=4))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'trustType', 'trustAttributes', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Parent-Child Domain Trusts'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}

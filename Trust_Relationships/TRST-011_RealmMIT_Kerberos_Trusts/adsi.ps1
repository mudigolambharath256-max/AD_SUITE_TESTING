# Check: Realm/MIT Kerberos Trusts
# Category: Trust Relationships
# Severity: medium
# ID: TRST-011
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=trustedDomain)(trustType=3))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'trustType', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Realm/MIT Kerberos Trusts'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}

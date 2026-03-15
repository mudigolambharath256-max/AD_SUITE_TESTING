# Check: Trusts with SID History Enabled
# Category: Trust Relationships
# Severity: medium
# ID: TRST-008
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectClass=trustedDomain)(trustAttributes:1.2.840.113556.1.4.803:=32))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'cn', 'flatName', 'trustAttributes', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Trusts with SID History Enabled'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}

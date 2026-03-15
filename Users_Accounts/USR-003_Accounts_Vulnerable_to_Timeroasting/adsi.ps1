# Check: Accounts Vulnerable to Timeroasting
# Category: Users & Accounts
# Severity: medium
# ID: USR-003
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(&(objectCategory=computer)(userPassword=*))'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'samAccountName', 'userPassword', 'objectSid') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Accounts Vulnerable to Timeroasting'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}

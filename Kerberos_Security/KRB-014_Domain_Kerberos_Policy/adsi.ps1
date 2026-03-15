# Check: Domain Kerberos Policy
# Category: Kerberos Security
# Severity: medium
# ID: KRB-014
# Requirements: None
# ============================================

# LDAP search (ADSI / DirectorySearcher)
$searcher = [ADSISearcher]'(objectClass=domainDNS)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'maxPwdAge', 'lockoutDuration', 'lockoutThreshold', 'msDS-SupportedEncryptionTypes') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label = 'Domain Kerberos Policy'
    Name = $p['name'][0]
    DistinguishedName = $p['distinguishedname'][0]
  }
}

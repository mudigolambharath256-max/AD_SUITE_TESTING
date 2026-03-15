# Check: Schema Master
# Category: Domain Controllers
# Severity: medium
# ID: DC-008
# Requirements: None
# ============================================

$root = [ADSI]"LDAP://RootDSE"
$searchRoot = [ADSI]("LDAP://CN=Schema," + $root.configurationNamingContext)
$searcher = New-Object System.DirectoryServices.DirectorySearcher($searchRoot)
$searcher.Filter = '(objectClass=dMD)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'fSMORoleOwner') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$results = $searcher.FindAll()
$results | ForEach-Object {
  $p = $_.Properties
  [PSCustomObject]@{
    Label             = 'Schema Master'
    name              = if ($p['name'] -and $p['name'].Count -gt 0) { $p['name'][0] } else { $null }
    distinguishedName = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { $null }
    fSMORoleOwner     = if ($p['fsmoroleowner'] -and $p['fsmoroleowner'].Count -gt 0) { $p['fsmoroleowner'][0] } else { $null }
  }
}

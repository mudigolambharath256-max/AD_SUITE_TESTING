# Check: FSMO Role Holders
# Category: Domain Controllers
# Severity: medium
# ID: DC-007
# Requirements: None
# ============================================

$root     = [ADSI]"LDAP://RootDSE"
$domainNC = $root.defaultNamingContext.ToString()
$searchRoot = [ADSI]("LDAP://" + $domainNC)
$searcher = New-Object System.DirectoryServices.DirectorySearcher($searchRoot)
$searcher.Filter = '(objectClass=domainDNS)'
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.Clear()
@('name', 'distinguishedName', 'fSMORoleOwner', 'rIDManagerReference') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }
$infraEntry = [ADSI]("LDAP://CN=Infrastructure," + $domainNC)
$infraOwner = if ($infraEntry -and $infraEntry.Properties['fSMORoleOwner'].Count -gt 0) {
    $infraEntry.Properties['fSMORoleOwner'][0]
} else { '(not set)' }
$domainResult = $searcher.FindOne()
if ($domainResult) {
    $p = $domainResult.Properties
    [PSCustomObject]@{
        Label                = 'FSMO Role Holders'
        name                 = if ($p['name'].Count -gt 0) { $p['name'][0] } else { $null }
        distinguishedName    = if ($p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { $null }
        FSMORoleOwner        = if ($p['fsmoroleowner'].Count -gt 0) { $p['fsmoroleowner'][0] } else { $null }
        RIDManagerReference  = if ($p['ridmanagerreference'].Count -gt 0) { $p['ridmanagerreference'][0] } else { $null }
        InfrastructureMaster = $infraOwner
    }
}

# Check: Admin SDHolder Template
# Category: Access_Control
# Severity: info
# ID: ACC-029
# Requirements: None
# ============================================

# LDAP Filter: (&(objectClass=container)(cn=AdminSDHolder))

[ADSISearcher] $searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.Filter = "(&(objectClass=container)(cn=AdminSDHolder))"
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.AddRange(@('name', 'distinguishedName', 'cn'))

$results = $searcher.FindAll()
$results | ForEach-Object {
    $obj = $_
    $props_dict = @{}
    foreach ($prop in $obj.Properties.PropertyNames) {
        $props_dict[$prop] = $obj.Properties[$prop][0]
    }
    [PSCustomObject]$props_dict
}


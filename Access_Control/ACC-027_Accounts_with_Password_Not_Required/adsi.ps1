# Check: Unconstrained Delegation Principals
# Category: Access_Control
# Severity: critical
# ID: ACC-027
# Requirements: None
# ============================================

# LDAP Filter: (&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=524288)(!(primaryGroupID=516)))

[ADSISearcher] $searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.Filter = "(&(!(userAccountControl:1.2.840.113556.1.4.803:=2))(userAccountControl:1.2.840.113556.1.4.803:=524288)(!(primaryGroupID=516)))"
$searcher.PageSize = 1000
$searcher.PropertiesToLoad.AddRange(@('name', 'distinguishedName', 'samAccountName', 'objectClass', 'userAccountControl'))

$results = $searcher.FindAll()
$results | ForEach-Object {
    $obj = $_
    $props_dict = @{}
    foreach ($prop in $obj.Properties.PropertyNames) {
        $props_dict[$prop] = $obj.Properties[$prop][0]
    }
    [PSCustomObject]$props_dict
}


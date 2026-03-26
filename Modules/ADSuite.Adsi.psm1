#requires -Version 5.1
<#
.SYNOPSIS
    Shared ADSI/LDAP helpers for AD Suite checks (RootDSE, DirectorySearcher, property extraction).
#>

function Get-ADSuiteRootDse {
    [CmdletBinding()]
    param(
        [string]$ServerName
    )
    $path = if ($ServerName) { "LDAP://$ServerName/RootDSE" } else { "LDAP://RootDSE" }
    try {
        $root = [ADSI]$path
        [PSCustomObject]@{
            DefaultNamingContext          = [string]$root.defaultNamingContext
            ConfigurationNamingContext    = [string]$root.configurationNamingContext
            SchemaNamingContext           = [string]$root.schemaNamingContext
            RootDomainNamingContext       = [string]$root.rootDomainNamingContext
            DnsHostName                   = if ($root.dnsHostName) { [string]$root.dnsHostName } else { $null }
            Raw                           = $root
        }
    } catch {
        throw "Get-ADSuiteRootDse failed: $_"
    }
}

function Resolve-ADSuiteSearchRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Domain', 'Configuration', 'Schema', 'SchemaContainer', 'Custom')]
        [string]$SearchBase,

        [string]$SearchBaseDn,

        [Parameter(Mandatory)]
        [object]$RootDse,

        [string]$ServerName
    )

    $rd = if ($RootDse -is [hashtable]) { $RootDse } else {
        @{
            DefaultNamingContext       = $RootDse.DefaultNamingContext
            ConfigurationNamingContext = $RootDse.ConfigurationNamingContext
            SchemaNamingContext        = $RootDse.SchemaNamingContext
        }
    }

    $dn = switch ($SearchBase) {
        'Domain' { $rd.DefaultNamingContext }
        'Configuration' { $rd.ConfigurationNamingContext }
        'Schema' { $rd.SchemaNamingContext }
        'SchemaContainer' {
            $cfg = $rd.ConfigurationNamingContext
            if (-not $cfg) { throw 'ConfigurationNamingContext is empty; cannot build SchemaContainer path.' }
            "CN=Schema,$cfg"
        }
        'Custom' {
            if (-not $SearchBaseDn) { throw 'searchBaseDn is required when searchBase is Custom.' }
            $SearchBaseDn
        }
    }

    $ldapUri = if ($ServerName) {
        "LDAP://$ServerName/$dn"
    } else {
        "LDAP://$dn"
    }

    try {
        [ADSI]$ldapUri
    } catch {
        throw "Resolve-ADSuiteSearchRoot failed for '$ldapUri': $_"
    }
}

function Invoke-ADSuiteLdapQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LdapFilter,

        [Parameter(Mandatory)]
        [System.DirectoryServices.DirectoryEntry]$SearchRoot,

        [ValidateSet('Base', 'OneLevel', 'Subtree')]
        [string]$SearchScope = 'Subtree',

        [string[]]$PropertiesToLoad = @(),

        [int]$PageSize = 1000
    )

    $searcher = New-Object System.DirectoryServices.DirectorySearcher($SearchRoot)
    try {
        $searcher.Filter = $LdapFilter
        $searcher.PageSize = $PageSize
        $searcher.SearchScope = [System.DirectoryServices.SearchScope]::$SearchScope
        $searcher.PropertiesToLoad.Clear()
        foreach ($p in $PropertiesToLoad) {
            if ($p) { [void]$searcher.PropertiesToLoad.Add($p) }
        }

        $collection = $searcher.FindAll()
        try {
            return @($collection)
        } finally {
            $collection.Dispose()
        }
    } finally {
        $searcher.Dispose()
    }
}

function Get-AdsProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Properties,

        [Parameter(Mandatory)]
        [string]$Name
    )
    if ($null -eq $Properties) { return $null }
    $key = $Name.ToLowerInvariant()
    if ($Properties.Contains($key) -and $Properties[$key].Count -gt 0) {
        return $Properties[$key][0]
    }
    return $null
}

function Test-UserAccountControlMask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $UserAccountControlValue,

        [int]$MustInclude = 0,
        [int]$MustExclude = 0
    )
    if ($null -eq $UserAccountControlValue -or $UserAccountControlValue -eq 'N/A') {
        return $false
    }
    [int]$uac = 0
    if (-not [int]::TryParse([string]$UserAccountControlValue, [ref]$uac)) {
        return $false
    }
    # MustInclude: every bit set in the mask must be set on UAC (typical for one flag, e.g. DONT_REQ_PREAUTH).
    if ($MustInclude -ne 0 -and (($uac -band $MustInclude) -ne $MustInclude)) {
        return $false
    }
    # MustExclude: object must not have any of these bits (e.g. exclude disabled accounts with ADS_UF_ACCOUNTDISABLE = 2).
    if ($MustExclude -ne 0 -and (($uac -band $MustExclude) -ne 0)) {
        return $false
    }
    return $true
}

function ConvertTo-ADSuiteFindingRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.DirectoryServices.SearchResult]$SearchResult,

        [Parameter(Mandatory)]
        [hashtable]$OutputMap,

        [string]$CheckId,
        [string]$CheckName
    )
    process {
        $props = $SearchResult.Properties
        $row = [ordered]@{}
        if ($CheckId) { $row['CheckId'] = $CheckId }
        if ($CheckName) { $row['CheckName'] = $CheckName }
        foreach ($entry in $OutputMap.GetEnumerator()) {
            $colName = $entry.Key
            $attrName = $entry.Value
            $val = Get-AdsProperty -Properties $props -Name $attrName
            if ($null -eq $val) { $val = 'N/A' }
            $row[$colName] = $val
        }
        [PSCustomObject]$row
    }
}

Export-ModuleMember -Function @(
    'Get-ADSuiteRootDse',
    'Resolve-ADSuiteSearchRoot',
    'Invoke-ADSuiteLdapQuery',
    'Get-AdsProperty',
    'Test-UserAccountControlMask',
    'ConvertTo-ADSuiteFindingRow'
)

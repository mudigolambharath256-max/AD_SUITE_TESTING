#requires -Version 5.1
<#
.SYNOPSIS
    Shared ADSI/LDAP helpers for AD Suite checks (RootDSE, DirectorySearcher, property extraction, batch scan).
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

function Merge-ADSuiteCheckDefaults {
    [CmdletBinding()]
    param(
        $Defaults,
        [Parameter(Mandatory)]
        $Check
    )
    $merged = @{}
    foreach ($p in $Check.PSObject.Properties) {
        $merged[$p.Name] = $p.Value
    }
    if ($Defaults) {
        foreach ($p in $Defaults.PSObject.Properties) {
            if (-not $merged.ContainsKey($p.Name)) {
                $merged[$p.Name] = $p.Value
            }
        }
    }
    [PSCustomObject]$merged
}

function Get-ADSuiteOptionalCheckMeta {
    param($Check)
    $remediation = $null
    if ($Check.PSObject.Properties.Name -contains 'remediation' -and $Check.remediation) {
        $remediation = [string]$Check.remediation
    }
    $references = $null
    if ($Check.PSObject.Properties.Name -contains 'references') {
        if ($Check.references -is [System.Array]) {
            $references = @($Check.references | ForEach-Object { [string]$_ })
        } elseif ($Check.references) {
            $references = [string]$Check.references
        }
    }
    $scoreWeight = 1.0
    if ($Check.PSObject.Properties.Name -contains 'scoreWeight' -and $null -ne $Check.scoreWeight) {
        $sw = [double]$Check.scoreWeight
        if ($sw -gt 0) { $scoreWeight = $sw }
    }
    @{
        Remediation = $remediation
        References  = $references
        ScoreWeight = $scoreWeight
    }
}

function Merge-ADSuiteCatalogOverrides {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Document,

        $OverridesDocument
    )
    if (-not $OverridesDocument -or -not $OverridesDocument.checks) {
        return $Document
    }
    $byId = @{}
    foreach ($c in @($Document.checks)) {
        $id = [string]$c.id
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        $byId[$id] = $c
    }
    foreach ($ov in @($OverridesDocument.checks)) {
        $id = [string]$ov.id
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        if (-not $byId.ContainsKey($id)) {
            Write-Warning "checks.overrides.json references unknown CheckId '$id' (skipped)."
            continue
        }
        $base = $byId[$id]
        foreach ($p in $ov.PSObject.Properties) {
            if ($p.Name -eq 'id') { continue }
            $base | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
        }
    }
    $Document
}

function Import-ADSuiteCatalogJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ChecksJsonPath,

        [string]$ChecksOverridesPath
    )
    $jsonText = Get-Content -LiteralPath $ChecksJsonPath -Raw -Encoding UTF8
    $doc = $jsonText | ConvertFrom-Json
    if (-not [string]::IsNullOrWhiteSpace($ChecksOverridesPath) -and (Test-Path -LiteralPath $ChecksOverridesPath)) {
        $ovText = Get-Content -LiteralPath $ChecksOverridesPath -Raw -Encoding UTF8
        $ovDoc = $ovText | ConvertFrom-Json
        $null = Merge-ADSuiteCatalogOverrides -Document $doc -OverridesDocument $ovDoc
    }
    $doc
}

function Test-ADSuiteCatalogIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Document
    )
    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    if (-not $Document.checks) {
        $errors.Add('Catalog has no ''checks'' array.')
        return [PSCustomObject]@{
            Errors            = @($errors)
            Warnings          = @($warnings)
            ChecksTotal       = 0
            DuplicateIds      = @()
            HasBlockingErrors = $true
        }
    }
    $list = @($Document.checks)
    $seen = @{}
    $dupMsg = @{}
    $dups = [System.Collections.Generic.List[string]]::new()
    foreach ($c in $list) {
        $id = [string]$c.id
        if ([string]::IsNullOrWhiteSpace($id)) {
            $errors.Add('A check entry is missing ''id''.')
            continue
        }
        if ($seen.ContainsKey($id)) {
            $dups.Add($id)
            if (-not $dupMsg.ContainsKey($id)) {
                $errors.Add("Duplicate CheckId: $id")
                $dupMsg[$id] = $true
            }
        } else {
            $seen[$id] = $true
        }
    }
    foreach ($c in $list) {
        $id = [string]$c.id
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        $eng = if ($c.engine) { $c.engine.ToLowerInvariant() } else { 'ldap' }
        if ($eng -eq 'inventory') { continue }
        if ($eng -eq 'ldap') {
            if (-not $c.searchBase) { $errors.Add("$id : ldap engine requires 'searchBase'.") }
            if (-not $c.ldapFilter) { $errors.Add("$id : ldap engine requires 'ldapFilter'.") }
        } elseif ($eng -eq 'filesystem') {
            if (-not $c.filesystemKind) { $errors.Add("$id : filesystem engine requires 'filesystemKind'.") }
        }
        if ($eng -in @('ldap', 'filesystem', 'registry')) {
            if (-not $c.severity) { $warnings.Add("$id : risk check should set 'severity'.") }
            if (-not $c.description) { $warnings.Add("$id : risk check should set 'description'.") }
        }
    }
    [PSCustomObject]@{
        Errors            = @($errors)
        Warnings          = @($warnings)
        ChecksTotal       = $list.Count
        DuplicateIds      = @($dups | Select-Object -Unique)
        HasBlockingErrors = ($errors.Count -gt 0)
    }
}

function ConvertTo-ADSuiteHashtableOutputMap {
    param($OutputProperties)
    if ($null -eq $OutputProperties) { return @{} }
    if ($OutputProperties -is [hashtable]) { return $OutputProperties }
    $h = @{}
    foreach ($p in $OutputProperties.PSObject.Properties) {
        $h[$p.Name] = [string]$p.Value
    }
    return $h
}

function Get-ADSuiteOutputPropertyMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Check
    )
    $map = ConvertTo-ADSuiteHashtableOutputMap -OutputProperties $Check.outputProperties
    if ($map.Count -gt 0) { return $map }
    $h = @{}
    if ($Check.propertiesToLoad) {
        foreach ($p in $Check.propertiesToLoad) {
            if ($p) { $h[$p] = $p }
        }
    }
    return $h
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
    if ($MustInclude -ne 0 -and (($uac -band $MustInclude) -ne $MustInclude)) {
        return $false
    }
    if ($MustExclude -ne 0 -and (($uac -band $MustExclude) -ne 0)) {
        return $false
    }
    return $true
}

function Get-ADSuiteFqdnFromDefaultNc {
    [CmdletBinding()]
    param([string]$DefaultNamingContext)
    if ([string]::IsNullOrWhiteSpace($DefaultNamingContext)) { return $null }
    $parts = $DefaultNamingContext -split ',' | Where-Object { $_ -like 'DC=*' } | ForEach-Object { $_.Substring(3) }
    if (-not $parts -or $parts.Count -eq 0) { return $null }
    return ($parts -join '.')
}

function Get-ADSuiteSeverityWeight {
    [CmdletBinding()]
    param([string]$Severity)
    if ([string]::IsNullOrWhiteSpace($Severity)) { return 3 }
    switch -Regex ($Severity.ToLowerInvariant()) {
        '^critical$' { return 5 }
        '^high$' { return 4 }
        '^medium$' { return 3 }
        '^low$' { return 2 }
        '^info$' { return 1 }
        default { return 3 }
    }
}

function Add-ADSuiteScanScores {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.IEnumerable]$Results,

        [int]$FindingCapPerCheck = 10,

        [int]$Normalizer = 5
    )
    $scoreByCategory = @{}
    [double]$globalRaw = 0
    foreach ($r in $Results) {
        $w = Get-ADSuiteSeverityWeight -Severity ([string]$r.Severity)
        $fc = 0
        if ($null -ne $r.FindingCount) { $fc = [int]$r.FindingCount }
        $score = 0
        $skipScore = ($r.Error -or $r.Result -eq 'Error' -or $r.Result -eq 'Skipped')
        $swMul = 1.0
        if ($null -ne $r.ScoreWeight) { $swMul = [double]$r.ScoreWeight }
        if ($swMul -le 0) { $swMul = 1.0 }
        if (-not $skipScore) {
            $score = $w * [Math]::Min($fc, $FindingCapPerCheck) * $swMul
        }
        $r | Add-Member -NotePropertyName CheckScore -NotePropertyValue $score -Force
        $globalRaw += $score
        $cat = if ($r.Category) { [string]$r.Category } else { 'Unknown' }
        if (-not $scoreByCategory.ContainsKey($cat)) { $scoreByCategory[$cat] = 0 }
        $scoreByCategory[$cat] += $score
    }
    $norm = [Math]::Max(1, $Normalizer)
    $globalScore = [Math]::Min(100, [Math]::Ceiling($globalRaw / $norm))
    @{
        GlobalRaw          = [int][Math]::Floor($globalRaw)
        GlobalScore        = $globalScore
        GlobalRiskBand     = if ($globalScore -le 30) { 'Low' } elseif ($globalScore -le 60) { 'Moderate' } elseif ($globalScore -le 80) { 'High' } else { 'Critical' }
        ScoreByCategory    = $scoreByCategory
        Normalizer         = $Normalizer
        FindingCapPerCheck = $FindingCapPerCheck
    }
}

function Invoke-ADSuiteFilesystemCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        $RootDse,

        [string]$ServerName,

        [string]$SourcePathOverride
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $cid = [string]$Check.id
    $cname = if ($Check.name) { [string]$Check.name } else { $cid }
    $cat = if ($Check.category) { [string]$Check.category } else { 'Unknown' }

    $resolvedSourcePath = $null
    if (-not [string]::IsNullOrWhiteSpace($SourcePathOverride)) {
        $resolvedSourcePath = $SourcePathOverride.Trim()
    } elseif ($Check.PSObject.Properties.Name -contains 'sourcePath' -and -not [string]::IsNullOrWhiteSpace([string]$Check.sourcePath)) {
        $resolvedSourcePath = [string]$Check.sourcePath
    }

    $severity = if ($Check.PSObject.Properties.Name -contains 'severity' -and $Check.severity) {
        [string]$Check.severity
    } else {
        'medium'
    }
    $description = $null
    if ($Check.PSObject.Properties.Name -contains 'description' -and $Check.description) {
        $description = [string]$Check.description
    }

    $meta = Get-ADSuiteOptionalCheckMeta -Check $Check

    $kind = if ($Check.PSObject.Properties.Name -contains 'filesystemKind' -and $Check.filesystemKind) {
        [string]$Check.filesystemKind
    } else {
        ''
    }

    if ($kind -ne 'SysvolPoliciesInsecureAcl') {
        $sw.Stop()
        return [PSCustomObject]@{
            CheckId       = $cid
            CheckName     = $cname
            Category      = $cat
            Severity      = $severity
            Description   = $description
            FindingCount  = 0
            Result        = 'Error'
            DurationMs    = [int]$sw.ElapsedMilliseconds
            Error         = "Unknown filesystemKind '$kind'. Supported: SysvolPoliciesInsecureAcl."
            ExitCode      = 1
            Findings      = [object[]]@()
            SourcePath    = $resolvedSourcePath
            Remediation   = $meta.Remediation
            References    = $meta.References
            ScoreWeight   = $meta.ScoreWeight
        }
    }

    $fqdn = Get-ADSuiteFqdnFromDefaultNc -DefaultNamingContext $RootDse.DefaultNamingContext
    if (-not $fqdn) {
        $sw.Stop()
        return [PSCustomObject]@{
            CheckId       = $cid
            CheckName     = $cname
            Category      = $cat
            Severity      = $severity
            Description   = $description
            FindingCount  = 0
            Result        = 'Error'
            DurationMs    = [int]$sw.ElapsedMilliseconds
            Error         = 'Could not derive DNS domain from defaultNamingContext.'
            ExitCode      = 1
            Findings      = [object[]]@()
            SourcePath    = $resolvedSourcePath
            Remediation   = $meta.Remediation
            References    = $meta.References
            ScoreWeight   = $meta.ScoreWeight
        }
    }

    $policiesPath = "\\$fqdn\SYSVOL\$fqdn\Policies"
    if ($Check.PSObject.Properties.Name -contains 'sysvolPoliciesPath' -and -not [string]::IsNullOrWhiteSpace([string]$Check.sysvolPoliciesPath)) {
        $policiesPath = [string]$Check.sysvolPoliciesPath
    }

    if (-not (Test-Path -LiteralPath $policiesPath)) {
        $sw.Stop()
        return [PSCustomObject]@{
            CheckId       = $cid
            CheckName     = $cname
            Category      = $cat
            Severity      = $severity
            Description   = $description
            FindingCount  = 0
            Result        = 'Error'
            DurationMs    = [int]$sw.ElapsedMilliseconds
            Error         = "SYSVOL Policies path not reachable: $policiesPath (run from domain-joined host with access to SYSVOL)."
            ExitCode      = 1
            Findings      = [object[]]@()
            SourcePath    = $resolvedSourcePath
            Remediation   = $meta.Remediation
            References    = $meta.References
            ScoreWeight   = $meta.ScoreWeight
        }
    }

    $fullMask = [int][System.Security.AccessControl.FileSystemRights]::FullControl
    $modMask = [int][System.Security.AccessControl.FileSystemRights]::Modify
    $writeMask = [int][System.Security.AccessControl.FileSystemRights]::Write

    $findingRows = [System.Collections.Generic.List[object]]::new()
    try {
        Get-ChildItem -LiteralPath $policiesPath -Directory -ErrorAction Stop | ForEach-Object {
            $dir = $_.FullName
            $acl = Get-Acl -LiteralPath $dir -ErrorAction Stop
            foreach ($ace in $acl.Access) {
                $idStr = [string]$ace.IdentityReference.Value
                $isWide = $false
                if ($idStr -match '(?i)(^Everyone$|\\Everyone$)') { $isWide = $true }
                if ($idStr -match '(?i)Authenticated Users') { $isWide = $true }
                if (-not $isWide) { continue }

                $rVal = [int]$ace.FileSystemRights
                $dangerous = (($rVal -band $fullMask) -ne 0) -or (($rVal -band $modMask) -ne 0) -or (($rVal -band $writeMask) -ne 0)
                if (-not $dangerous) { continue }

                $findingRows.Add([PSCustomObject]@{
                        GpoFolder          = $dir
                        IdentityReference  = $idStr
                        FileSystemRights   = $ace.FileSystemRights.ToString()
                        AccessControlType  = $ace.AccessControlType.ToString()
                    })
            }
        }
    } catch {
        $sw.Stop()
        return [PSCustomObject]@{
            CheckId       = $cid
            CheckName     = $cname
            Category      = $cat
            Severity      = $severity
            Description   = $description
            FindingCount  = 0
            Result        = 'Error'
            DurationMs    = [int]$sw.ElapsedMilliseconds
            Error         = "Filesystem scan failed: $($_.Exception.Message)"
            ExitCode      = 1
            Findings      = [object[]]@()
            SourcePath    = $resolvedSourcePath
            Remediation   = $meta.Remediation
            References    = $meta.References
            ScoreWeight   = $meta.ScoreWeight
        }
    }

    $fc = $findingRows.Count
    $resultWord = if ($fc -eq 0) { 'Pass' } else { 'Fail' }

    $rows = foreach ($row in $findingRows) {
        $o = [ordered]@{}
        foreach ($p in $row.PSObject.Properties) { $o[$p.Name] = $p.Value }
        $o['CheckId'] = $cid
        $o['CheckName'] = $cname
        $o['FindingCount'] = $fc
        $o['Result'] = $resultWord
        $o['Severity'] = $severity
        if ($description) { $o['Description'] = $description }
        if ($resolvedSourcePath) { $o['SourcePath'] = $resolvedSourcePath }
        [PSCustomObject]$o
    }

    $sw.Stop()
    return [PSCustomObject]@{
        CheckId       = $cid
        CheckName     = $cname
        Category      = $cat
        Severity      = $severity
        Description   = $description
        FindingCount  = $fc
        Result        = $resultWord
        DurationMs    = [int]$sw.ElapsedMilliseconds
        Error         = $null
        ExitCode      = 0
        Findings      = @($rows)
        SourcePath    = $resolvedSourcePath
        Remediation   = $meta.Remediation
        References    = $meta.References
        ScoreWeight   = $meta.ScoreWeight
    }
}

function Invoke-ADSuiteLdapCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        $RootDse,

        [string]$ServerName,

        [string]$SourcePathOverride
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $cid = [string]$Check.id
    $cname = if ($Check.name) { [string]$Check.name } else { $cid }
    $cat = if ($Check.category) { [string]$Check.category } else { 'Unknown' }

    $resolvedSourcePath = $null
    if (-not [string]::IsNullOrWhiteSpace($SourcePathOverride)) {
        $resolvedSourcePath = $SourcePathOverride.Trim()
    } elseif ($Check.PSObject.Properties.Name -contains 'sourcePath' -and -not [string]::IsNullOrWhiteSpace([string]$Check.sourcePath)) {
        $resolvedSourcePath = [string]$Check.sourcePath
    }

    $severity = if ($Check.PSObject.Properties.Name -contains 'severity' -and $Check.severity) {
        [string]$Check.severity
    } else {
        'medium'
    }
    $description = $null
    if ($Check.PSObject.Properties.Name -contains 'description' -and $Check.description) {
        $description = [string]$Check.description
    }

    $meta = Get-ADSuiteOptionalCheckMeta -Check $Check

    $engine = if ($Check.engine) { $Check.engine.ToLowerInvariant() } else { 'ldap' }
    if ($engine -ne 'ldap') {
        $sw.Stop()
        return [PSCustomObject]@{
            CheckId       = $cid
            CheckName     = $cname
            Category      = $cat
            Severity      = $severity
            Description   = $description
            FindingCount  = 0
            Result        = 'Skipped'
            DurationMs    = [int]$sw.ElapsedMilliseconds
            Error         = "Check '$cid' uses engine '$engine', not ldap."
            ExitCode      = 2
            Findings      = [object[]]@()
            SourcePath    = $resolvedSourcePath
            Remediation   = $meta.Remediation
            References    = $meta.References
            ScoreWeight   = $meta.ScoreWeight
        }
    }

    if (-not $Check.searchBase) {
        $sw.Stop()
        return [PSCustomObject]@{
            CheckId       = $cid
            CheckName     = $cname
            Category      = $cat
            Severity      = $severity
            Description   = $description
            FindingCount  = 0
            Result        = 'Error'
            DurationMs    = [int]$sw.ElapsedMilliseconds
            Error         = "Check '$cid' is missing required field 'searchBase'."
            ExitCode      = 1
            Findings      = [object[]]@()
            SourcePath    = $resolvedSourcePath
            Remediation   = $meta.Remediation
            References    = $meta.References
            ScoreWeight   = $meta.ScoreWeight
        }
    }

    $ldapFilter = $Check.ldapFilter
    if (-not $ldapFilter) {
        $sw.Stop()
        return [PSCustomObject]@{
            CheckId       = $cid
            CheckName     = $cname
            Category      = $cat
            Severity      = $severity
            Description   = $description
            FindingCount  = 0
            Result        = 'Error'
            DurationMs    = [int]$sw.ElapsedMilliseconds
            Error         = "Check '$cid' has no ldapFilter."
            ExitCode      = 1
            Findings      = [object[]]@()
            SourcePath    = $resolvedSourcePath
            Remediation   = $meta.Remediation
            References    = $meta.References
            ScoreWeight   = $meta.ScoreWeight
        }
    }

    $searchBaseDn = $null
    if ($Check.PSObject.Properties.Name -contains 'searchBaseDn') {
        $searchBaseDn = $Check.searchBaseDn
    }

    try {
        $searchRoot = Resolve-ADSuiteSearchRoot -SearchBase $Check.searchBase -SearchBaseDn $searchBaseDn -RootDse $RootDse -ServerName $ServerName
    } catch {
        $sw.Stop()
        return [PSCustomObject]@{
            CheckId       = $cid
            CheckName     = $cname
            Category      = $cat
            Severity      = $severity
            Description   = $description
            FindingCount  = 0
            Result        = 'Error'
            DurationMs    = [int]$sw.ElapsedMilliseconds
            Error         = $_.Exception.Message
            ExitCode      = 1
            Findings      = [object[]]@()
            SourcePath    = $resolvedSourcePath
            Remediation   = $meta.Remediation
            References    = $meta.References
            ScoreWeight   = $meta.ScoreWeight
        }
    }

    $scope = if ($Check.searchScope) { $Check.searchScope } else { 'Subtree' }
    $pageSize = [int]($Check.pageSize)
    if ($pageSize -lt 1) { $pageSize = 1000 }

    $propsToLoad = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    if ($Check.propertiesToLoad) {
        foreach ($p in $Check.propertiesToLoad) {
            if ($p) { [void]$propsToLoad.Add($p) }
        }
    }
    [void]$propsToLoad.Add('distinguishedName')

    $mustInc = 0
    $mustExc = 0
    if ($null -ne $Check.userAccountControlMustInclude) { $mustInc = [int]$Check.userAccountControlMustInclude }
    if ($null -ne $Check.userAccountControlMustExclude) { $mustExc = [int]$Check.userAccountControlMustExclude }
    if ($mustInc -ne 0 -or $mustExc -ne 0) {
        [void]$propsToLoad.Add('userAccountControl')
    }

    if ($Check.PSObject.Properties.Name -contains 'excludeSamAccountName' -and $Check.excludeSamAccountName) {
        [void]$propsToLoad.Add('samAccountName')
    }

    try {
        $results = Invoke-ADSuiteLdapQuery -LdapFilter $ldapFilter -SearchRoot $searchRoot -SearchScope $scope -PropertiesToLoad @($propsToLoad) -PageSize $pageSize
    } catch {
        $sw.Stop()
        return [PSCustomObject]@{
            CheckId       = $cid
            CheckName     = $cname
            Category      = $cat
            Severity      = $severity
            Description   = $description
            FindingCount  = 0
            Result        = 'Error'
            DurationMs    = [int]$sw.ElapsedMilliseconds
            Error         = "LDAP query failed: $($_.Exception.Message)"
            ExitCode      = 1
            Findings      = [object[]]@()
            SourcePath    = $resolvedSourcePath
            Remediation   = $meta.Remediation
            References    = $meta.References
            ScoreWeight   = $meta.ScoreWeight
        }
    }

    $filtered = [System.Collections.Generic.List[object]]::new()
    foreach ($sr in $results) {
        if ($mustInc -ne 0 -or $mustExc -ne 0) {
            $uacVal = Get-AdsProperty -Properties $sr.Properties -Name 'userAccountControl'
            if (-not (Test-UserAccountControlMask -UserAccountControlValue $uacVal -MustInclude $mustInc -MustExclude $mustExc)) {
                continue
            }
        }
        $filtered.Add($sr)
    }

    $excludeSams = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    if ($Check.PSObject.Properties.Name -contains 'excludeSamAccountName' -and $Check.excludeSamAccountName) {
        foreach ($x in @($Check.excludeSamAccountName)) {
            if ($x) { [void]$excludeSams.Add([string]$x) }
        }
    }
    if ($excludeSams.Count -gt 0) {
        $filtered2 = [System.Collections.Generic.List[object]]::new()
        foreach ($sr in $filtered) {
            $sam = Get-AdsProperty -Properties $sr.Properties -Name 'samAccountName'
            $s = if ($null -eq $sam) { '' } elseif ($sam -is [System.Array]) { [string]$sam[0] } else { [string]$sam }
            if ($excludeSams.Contains($s)) { continue }
            $filtered2.Add($sr)
        }
        $filtered = $filtered2
    }

    $outputMap = Get-ADSuiteOutputPropertyMap -Check $Check
    if ($outputMap.Count -eq 0) {
        foreach ($p in $propsToLoad) {
            $outputMap[$p] = $p
        }
    }

    $findingCount = $filtered.Count
    $resultWord = if ($findingCount -eq 0) { 'Pass' } else { 'Fail' }

    $rows = foreach ($sr in $filtered) {
        $props = $sr.Properties
        $row = [ordered]@{}
        foreach ($entry in $outputMap.GetEnumerator()) {
            $colName = $entry.Key
            $attrName = $entry.Value
            $val = Get-AdsProperty -Properties $props -Name $attrName
            if ($null -eq $val) { $val = 'N/A' }
            $row[$colName] = $val
        }
        $row['CheckId'] = $cid
        $row['CheckName'] = $cname
        $row['FindingCount'] = $findingCount
        $row['Result'] = $resultWord
        $row['Severity'] = $severity
        if ($description) { $row['Description'] = $description }
        if ($resolvedSourcePath) {
            $row['SourcePath'] = $resolvedSourcePath
        }
        [PSCustomObject]$row
    }

    $sw.Stop()
    return [PSCustomObject]@{
        CheckId       = $cid
        CheckName     = $cname
        Category      = $cat
        Severity      = $severity
        Description   = $description
        FindingCount  = $findingCount
        Result        = $resultWord
        DurationMs    = [int]$sw.ElapsedMilliseconds
        Error         = $null
        ExitCode      = 0
        Findings      = @($rows)
        SourcePath    = $resolvedSourcePath
        Remediation   = $meta.Remediation
        References    = $meta.References
        ScoreWeight   = $meta.ScoreWeight
    }
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

function Export-ADSuiteHtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $ScanDocument,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [string]$Title = 'AD Suite Scan Report'
    )

    $enc = [System.Text.Encoding]::UTF8
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine('<!DOCTYPE html>')
    $null = $sb.AppendLine('<html lang="en"><head><meta charset="utf-8"/>')
    $null = $sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1"/>')
    $null = $sb.AppendLine("<title>$([System.Net.WebUtility]::HtmlEncode($Title))</title>")
    $null = $sb.AppendLine('<style>
body{font-family:Segoe UI,system-ui,sans-serif;margin:1rem 1.5rem;line-height:1.4;color:#222}
h1{font-size:1.35rem;border-bottom:1px solid #ccc;padding-bottom:.35rem}
h2{font-size:1.1rem;margin-top:1.25rem}
.meta{color:#555;font-size:.9rem;margin:.5rem 0}
.summary{display:flex;flex-wrap:wrap;gap:1rem;margin:1rem 0}
.box{border:1px solid #ddd;border-radius:4px;padding:.75rem 1rem;min-width:10rem;background:#fafafa}
.box strong{display:block;font-size:1.4rem}
table{border-collapse:collapse;width:100%;margin:.5rem 0;font-size:.85rem}
th,td{border:1px solid #ddd;padding:.35rem .5rem;text-align:left;vertical-align:top}
th{background:#f0f0f0}
tr:nth-child(even){background:#fafafa}
.pass{color:#0a0}
.fail{color:#a50}
.err{color:#a00}
section.check{margin:1.5rem 0;padding:1rem;border:1px solid #e0e0e0;border-radius:4px}
.small{font-size:.8rem;color:#666}
.risk-low{color:#0a0}
.risk-mod{color:#a50}
.risk-high{color:#c40}
.risk-crit{color:#a00;font-weight:bold}
.sev-info{color:#666}
.sev-low{color:#555}
.sev-medium{color:#8a6d00}
.sev-high{color:#c50;font-weight:bold}
.sev-critical{color:#a00;font-weight:bold}
.top10{margin:1rem 0}
@media print{body{margin:.5rem}}
</style></head><body>')

    $null = $sb.AppendLine("<h1>$([System.Net.WebUtility]::HtmlEncode($Title))</h1>")
    $meta = $ScanDocument.meta
    if ($meta) {
        $null = $sb.AppendLine('<div class="meta">')
        if ($meta.scanTimeUtc) { $null = $sb.AppendLine("Generated (UTC): $([System.Net.WebUtility]::HtmlEncode([string]$meta.scanTimeUtc))<br/>") }
        if ($meta.serverName) { $null = $sb.AppendLine("Server: $([System.Net.WebUtility]::HtmlEncode([string]$meta.serverName))<br/>") }
        if ($meta.defaultNamingContext) { $null = $sb.AppendLine("Default NC: $([System.Net.WebUtility]::HtmlEncode([string]$meta.defaultNamingContext))<br/>") }
        if ($meta.checksJsonPath) { $null = $sb.AppendLine("Catalog: $([System.Net.WebUtility]::HtmlEncode([string]$meta.checksJsonPath))<br/>") }
        if ($meta.checksOverridesPath) { $null = $sb.AppendLine("Overrides: $([System.Net.WebUtility]::HtmlEncode([string]$meta.checksOverridesPath))<br/>") }
        if ($meta.packName -or $meta.packVersion) {
            $pk = if ($meta.packName) { [string]$meta.packName } else { 'Curated risk pack' }
            $pv = if ($meta.packVersion) { " v$([string]$meta.packVersion)" } else { '' }
            $pd = if ($meta.packDateUtc) { " ($([string]$meta.packDateUtc))" } else { '' }
            $null = $sb.AppendLine("Rule pack: $([System.Net.WebUtility]::HtmlEncode($pk))$([System.Net.WebUtility]::HtmlEncode($pv))$([System.Net.WebUtility]::HtmlEncode($pd))<br/>")
        }
        $null = $sb.AppendLine('</div>')
    }

    $null = $sb.AppendLine('<p class="small" style="margin-top:.75rem;padding:.5rem .75rem;background:#f5f5f5;border-radius:4px;border:1px solid #e0e0e0">Interactive dashboard (load <code>scan-results.json</code> from this folder): <a href="../../ui/dashboard.html">Open <code>ui/dashboard.html</code></a> — use this link when the report file is under <code>out/&lt;run&gt;/report.html</code> in the repo clone; otherwise open the dashboard from the repository <code>ui</code> folder manually.</p>')

    $agg = $ScanDocument.aggregate
    if ($agg) {
        $null = $sb.AppendLine('<div class="summary">')
        $gsVal = $null
        if ($agg -is [hashtable]) {
            if ($agg.ContainsKey('globalScore')) { $gsVal = $agg['globalScore'] }
        } elseif ($agg.PSObject.Properties.Name -contains 'globalScore') {
            $gsVal = $agg.globalScore
        }
        if ($null -ne $gsVal) {
            $gs = [int]$gsVal
            $band = $null
            if ($agg -is [hashtable] -and $agg.ContainsKey('globalRiskBand')) { $band = [string]$agg['globalRiskBand'] }
            elseif ($agg.PSObject.Properties.Name -contains 'globalRiskBand' -and $agg.globalRiskBand) { $band = [string]$agg.globalRiskBand }
            if (-not $band) {
                if ($gs -le 30) { $band = 'Low' } elseif ($gs -le 60) { $band = 'Moderate' } elseif ($gs -le 80) { $band = 'High' } else { $band = 'Critical' }
            }
            $rc = 'risk-mod'
            if ($band -eq 'Low') { $rc = 'risk-low' }
            elseif ($band -eq 'Moderate') { $rc = 'risk-mod' }
            elseif ($band -eq 'High') { $rc = 'risk-high' }
            else { $rc = 'risk-crit' }
            $rawVal = $null
            if ($agg -is [hashtable] -and $agg.ContainsKey('globalRaw')) { $rawVal = $agg['globalRaw'] }
            elseif ($agg.PSObject.Properties.Name -contains 'globalRaw') { $rawVal = $agg.globalRaw }
            $rawTxt = if ($null -ne $rawVal) { " (raw: $rawVal)" } else { '' }
            $null = $sb.AppendLine("<div class='box'><span>Global risk score</span><strong class='$rc'>$gs / 100</strong><div class='small'>$band$rawTxt</div></div>")
        }
        $null = $sb.AppendLine("<div class='box'><span>Checks run</span><strong>$($agg.checksRun)</strong></div>")
        $null = $sb.AppendLine("<div class='box'><span>With findings</span><strong class='fail'>$($agg.checksWithFindings)</strong></div>")
        $null = $sb.AppendLine("<div class='box'><span>Errors</span><strong class='err'>$($agg.checksWithErrors)</strong></div>")
        $null = $sb.AppendLine("<div class='box'><span>Total findings</span><strong>$($agg.totalFindings)</strong></div>")
        $null = $sb.AppendLine('</div>')
    }

    $resultsForTop = $ScanDocument.results
    if ($resultsForTop) {
        $top = @($resultsForTop | Where-Object { $null -ne $_.CheckScore -and [int]$_.CheckScore -gt 0 } | Sort-Object -Property CheckScore -Descending | Select-Object -First 10)
        if ($top.Count -gt 0) {
            $null = $sb.AppendLine('<h2>Top 10 risks (by score)</h2><table class="top10"><thead><tr><th>CheckId</th><th>Name</th><th>Category</th><th>Severity</th><th>Findings</th><th>Score</th></tr></thead><tbody>')
            foreach ($t in $top) {
                $sevRaw = if ($t.Severity) { [string]$t.Severity } else { 'medium' }
                $sev = [System.Net.WebUtility]::HtmlEncode($sevRaw)
                $sc = 'sev-medium'
                switch -Regex ($sevRaw.ToLowerInvariant()) {
                    '^critical$' { $sc = 'sev-critical' }
                    '^high$' { $sc = 'sev-high' }
                    '^medium$' { $sc = 'sev-medium' }
                    '^low$' { $sc = 'sev-low' }
                    '^info$' { $sc = 'sev-info' }
                }
                $null = $sb.AppendLine((
                        "<tr><td>{0}</td><td>{1}</td><td>{2}</td><td class='{3}'>{4}</td><td>{5}</td><td>{6}</td></tr>"
                    ) -f
                    ([System.Net.WebUtility]::HtmlEncode([string]$t.CheckId)),
                    ([System.Net.WebUtility]::HtmlEncode([string]$t.CheckName)),
                    ([System.Net.WebUtility]::HtmlEncode([string]$t.Category)),
                    $sc,
                    $sev,
                    $t.FindingCount,
                    $t.CheckScore)
            }
            $null = $sb.AppendLine('</tbody></table>')
        }
    }

    $byCat = $ScanDocument.byCategory
    if ($byCat -and $byCat.Count -gt 0) {
        $null = $sb.AppendLine('<h2>By category</h2><table><thead><tr><th>Category</th><th>Checks</th><th>With findings</th><th>Errors</th></tr></thead><tbody>')
        foreach ($c in ($byCat.GetEnumerator() | Sort-Object { $_.Key })) {
            $k = $c.Key
            $v = $c.Value
            $null = $sb.AppendLine("<tr><td>$([System.Net.WebUtility]::HtmlEncode([string]$k))</td><td>$($v.checks)</td><td>$($v.withFindings)</td><td>$($v.errors)</td></tr>")
        }
        $null = $sb.AppendLine('</tbody></table>')
    }

    $results = $ScanDocument.results
    if ($results) {
        $null = $sb.AppendLine('<h2>Checks</h2>')
        foreach ($r in $results) {
            $rc = 'pass'
            if ($r.Result -eq 'Fail') { $rc = 'fail' }
            elseif ($r.Result -eq 'Error' -or $r.Error) { $rc = 'err' }
            $sevClass = 'sev-medium'
            if ($r.Severity) {
                switch -Regex ($r.Severity.ToString().ToLowerInvariant()) {
                    '^critical$' { $sevClass = 'sev-critical' }
                    '^high$' { $sevClass = 'sev-high' }
                    '^medium$' { $sevClass = 'sev-medium' }
                    '^low$' { $sevClass = 'sev-low' }
                    '^info$' { $sevClass = 'sev-info' }
                }
            }
            $scoreTxt = if ($null -ne $r.CheckScore) { " | Score: $($r.CheckScore)" } else { '' }
            $null = $sb.AppendLine("<section class='check'><h3>$([System.Net.WebUtility]::HtmlEncode([string]$r.CheckId)): $([System.Net.WebUtility]::HtmlEncode([string]$r.CheckName)) <span class='$rc'>$([System.Net.WebUtility]::HtmlEncode([string]$r.Result))</span></h3>")
            $null = $sb.AppendLine("<p class='small'>Category: $([System.Net.WebUtility]::HtmlEncode([string]$r.Category)) | <span class='$sevClass'>Severity: $([System.Net.WebUtility]::HtmlEncode([string]$r.Severity))</span> | Findings: $($r.FindingCount) | Duration: $($r.DurationMs) ms$scoreTxt</p>")
            if ($r.Description) {
                $null = $sb.AppendLine("<p>$([System.Net.WebUtility]::HtmlEncode([string]$r.Description))</p>")
            }
            if ($r.Remediation) {
                $null = $sb.AppendLine("<p><strong>Remediation:</strong> $([System.Net.WebUtility]::HtmlEncode([string]$r.Remediation))</p>")
            }
            if ($r.References) {
                $refs = $r.References
                if ($refs -is [System.Array]) {
                    $null = $sb.AppendLine('<p><strong>References:</strong></p><ul class="small">')
                    foreach ($ref in $refs) {
                        $null = $sb.AppendLine("<li>$([System.Net.WebUtility]::HtmlEncode([string]$ref))</li>")
                    }
                    $null = $sb.AppendLine('</ul>')
                } else {
                    $null = $sb.AppendLine("<p><strong>References:</strong> $([System.Net.WebUtility]::HtmlEncode([string]$refs))</p>")
                }
            }
            if ($r.Error) {
                $null = $sb.AppendLine("<p class='err'><strong>Error:</strong> $([System.Net.WebUtility]::HtmlEncode([string]$r.Error))</p>")
            }
            $findings = $r.Findings
            if ($findings -and @($findings).Count -gt 0) {
                $first = $findings[0]
                $cols = $first.PSObject.Properties.Name
                $null = $sb.AppendLine('<table><thead><tr>')
                foreach ($col in $cols) {
                    $null = $sb.AppendLine("<th>$([System.Net.WebUtility]::HtmlEncode([string]$col))</th>")
                }
                $null = $sb.AppendLine('</tr></thead><tbody>')
                foreach ($f in $findings) {
                    $null = $sb.AppendLine('<tr>')
                    foreach ($col in $cols) {
                        $cell = $f.$col
                        $s = if ($null -eq $cell) { '' } else { [string]$cell }
                        $null = $sb.AppendLine("<td>$([System.Net.WebUtility]::HtmlEncode($s))</td>")
                    }
                    $null = $sb.AppendLine('</tr>')
                }
                $null = $sb.AppendLine('</tbody></table>')
            } elseif (-not $r.Error -and $r.FindingCount -eq 0) {
                $null = $sb.AppendLine('<p class="pass">No findings (Pass).</p>')
            }
            $null = $sb.AppendLine('</section>')
        }
    }

    $null = $sb.AppendLine('</body></html>')
    [System.IO.File]::WriteAllText($OutputPath, $sb.ToString(), $enc)
}

Export-ModuleMember -Function @(
    'Get-ADSuiteRootDse',
    'Merge-ADSuiteCheckDefaults',
    'Merge-ADSuiteCatalogOverrides',
    'Import-ADSuiteCatalogJson',
    'Test-ADSuiteCatalogIntegrity',
    'Get-ADSuiteFqdnFromDefaultNc',
    'Get-ADSuiteSeverityWeight',
    'Get-ADSuiteOptionalCheckMeta',
    'Add-ADSuiteScanScores',
    'Resolve-ADSuiteSearchRoot',
    'Invoke-ADSuiteLdapQuery',
    'Invoke-ADSuiteLdapCheck',
    'Invoke-ADSuiteFilesystemCheck',
    'Get-AdsProperty',
    'Test-UserAccountControlMask',
    'Get-ADSuiteOutputPropertyMap',
    'ConvertTo-ADSuiteFindingRow',
    'Export-ADSuiteHtmlReport'
)

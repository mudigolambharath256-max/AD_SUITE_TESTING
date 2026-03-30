#requires -Version 5.1
<#
.SYNOPSIS
    AD CS ESC1–ESC8 checks via ADSI/LDAP (Certificate Services module for AD Suite).
.NOTES
    Loaded by Invoke-ADSuiteAdcsCheck; do not dot-source with top-level params.
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

function Set-ADSuiteAdcsSession {
    [CmdletBinding()]
    param(
        [string]$ServerName,
        [System.Management.Automation.PSCredential]$Credential,
        [bool]$SkipACLChecks,
        [bool]$SkipNetworkProbes
    )
    $script:DomainController = $ServerName
    $script:Credential = $Credential
    $script:SkipACLChecks = $SkipACLChecks
    $script:SkipNetworkProbes = $SkipNetworkProbes
}

#region Constants
$script:EKU = [ordered]@{
    ClientAuthentication = '1.3.6.1.5.5.7.3.2'
    PKINITClientAuth     = '1.3.6.1.5.2.3.4'
    SmartCardLogon       = '1.3.6.1.4.1.311.20.2.2'
    AnyPurpose           = '2.5.29.37.0'
    CertRequestAgent     = '1.3.6.1.4.1.311.20.2.1'
    CodeSigning          = '1.3.6.1.5.5.7.3.3'
    OCSPSigning          = '1.3.6.1.5.5.7.3.9'
    ServerAuthentication = '1.3.6.1.5.5.7.3.1'
}
$script:CertNameFlag = [ordered]@{
    EnrolleeSuppliesSubject = [long]0x00000001
}
$script:EnrollFlag = [ordered]@{
    ManagerApprovalRequired = [long]0x00000002
}
$script:EnrollmentRightGuid = [GUID]'0e10c968-78fb-11d2-90d4-00c04f79dc55'
$script:AutoEnrollmentRightGuid = [GUID]'a05b8cc2-17bc-4802-a710-e7c15ab866a2'
$script:AllGuid = [GUID]'00000000-0000-0000-0000-000000000000'
$script:EDITF_ATTRIBUTESUBJECTALTNAME2 = [long]0x00040000
$script:PrivilegedSIDs = @(
    'S-1-5-18', 'S-1-5-32-544', 'S-1-5-9', 'S-1-5-32-549'
)
$script:PrivilegedSIDPatterns = @(
    'S-1-5-21-\d+-\d+-\d+-512$', 'S-1-5-21-\d+-\d+-\d+-519$', 'S-1-5-21-\d+-\d+-\d+-516$',
    'S-1-5-21-\d+-\d+-\d+-498$'
)
$script:WriteRights =
    [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite -bor
    [System.DirectoryServices.ActiveDirectoryRights]::GenericAll -bor
    [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl -bor
    [System.DirectoryServices.ActiveDirectoryRights]::WriteOwner -bor
    [System.DirectoryServices.ActiveDirectoryRights]::WriteProperty
$script:LDAP_MATCHING_RULE_BIT_AND = '1.2.840.113556.1.4.803'
#endregion

#region ADSI
function Get-ADSIRootDSE {
    if ($script:DomainController) {
        return [ADSI]"LDAP://$($script:DomainController)/RootDSE"
    }
    return [ADSI]'LDAP://RootDSE'
}

function Build-LDAPPath {
    param([string]$DN)
    if ($script:DomainController) { return "LDAP://$($script:DomainController)/$DN" }
    return "LDAP://$DN"
}

function New-ADSISearcher {
    param(
        [Parameter(Mandatory)][string]$SearchBase,
        [Parameter(Mandatory)][string]$Filter,
        [string[]]$Properties,
        [System.DirectoryServices.SearchScope]$Scope = 'Subtree',
        [switch]$ReadACL
    )
    $de = [ADSI](Build-LDAPPath -DN $SearchBase)
    if ($script:Credential) {
        $de.Username = $script:Credential.UserName
        $de.Password = $script:Credential.GetNetworkCredential().Password
    }
    $searcher = New-Object System.DirectoryServices.DirectorySearcher($de)
    $searcher.Filter = $Filter
    $searcher.SearchScope = $Scope
    $searcher.PageSize = 1000
    if ($ReadACL) {
        $searcher.SecurityMasks =
            [System.DirectoryServices.SecurityMasks]::Dacl -bor
            [System.DirectoryServices.SecurityMasks]::Owner
    }
    if ($Properties) {
        $searcher.PropertiesToLoad.Clear()
        foreach ($p in $Properties) { [void]$searcher.PropertiesToLoad.Add($p) }
        if ($ReadACL -and 'nTSecurityDescriptor' -notin $Properties) {
            [void]$searcher.PropertiesToLoad.Add('nTSecurityDescriptor')
        }
    }
    return $searcher
}

function Get-Prop { param($Result, [string]$Name)
    if ($Result.Properties[$Name] -and $Result.Properties[$Name].Count -gt 0) {
        return $Result.Properties[$Name][0]
    }
    return $null
}

function Get-MultiProp { param($Result, [string]$Name)
    if ($Result.Properties[$Name] -and $Result.Properties[$Name].Count -gt 0) {
        return @($Result.Properties[$Name])
    }
    return @()
}

function Test-Bit { param([long]$Value, [long]$Bit)
    return ($Value -band $Bit) -eq $Bit
}

function Get-FriendlyEKUList {
    param([string[]]$OIDs)
    if (-not $OIDs -or $OIDs.Count -eq 0) { return '(None — Any Purpose)' }
    $names = foreach ($oid in $OIDs) {
        $match = $script:EKU.GetEnumerator() | Where-Object { $_.Value -eq $oid }
        if ($match) { $match.Key } else { $oid }
    }
    return $names -join ', '
}

function New-AdcsFindingObject {
    param(
        [string]$CheckID,
        [ValidateSet('Critical','High','Medium','Low','Info')]
        [string]$Severity,
        [string]$Title,
        [string]$Description,
        [string[]]$AffectedObjects = @(),
        [string]$Remediation = '',
        [hashtable]$RawData = @{}
    )
    [PSCustomObject]@{
        PSTypeName      = 'ADSuite.Finding.ADCS'
        CheckID         = $CheckID
        Severity        = $Severity
        Category        = 'Certificate Services'
        Title           = $Title
        Description     = $Description
        AffectedObjects = $AffectedObjects
        Remediation     = $Remediation
        RawData         = $RawData
        Timestamp       = (Get-Date -Format 'o')
    }
}
#endregion

#region ACL
function Test-IsPrivilegedSID {
    param([string]$SID)
    if ($SID -in $script:PrivilegedSIDs) { return $true }
    foreach ($pattern in $script:PrivilegedSIDPatterns) {
        if ($SID -match $pattern) { return $true }
    }
    return $false
}

function Resolve-SIDToName {
    param([System.Security.Principal.SecurityIdentifier]$SID)
    try { return $SID.Translate([System.Security.Principal.NTAccount]).Value }
    catch { return $SID.Value }
}

function Get-EnrollACEPrincipals {
    param([System.DirectoryServices.SearchResult]$SearchResult)
    $enrollees = [System.Collections.Generic.List[string]]::new()
    try {
        $de = $SearchResult.GetDirectoryEntry()
        $acl = $de.ObjectSecurity
        foreach ($ace in $acl.Access) {
            if ($ace.AccessControlType -ne 'Allow') { continue }
            $sid = $ace.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier])
            $sidStr = $sid.Value
            if (Test-IsPrivilegedSID -SID $sidStr) { continue }
            $hasEnroll = $false
            if ($ace.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::GenericAll) {
                $hasEnroll = $true
            }
            elseif ($ace.ActiveDirectoryRights -band [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight) {
                $guid = $ace.ObjectType
                if ($guid -eq $script:EnrollmentRightGuid -or $guid -eq $script:AutoEnrollmentRightGuid -or $guid -eq $script:AllGuid) {
                    $hasEnroll = $true
                }
            }
            if ($hasEnroll) { $enrollees.Add((Resolve-SIDToName -SID $sid)) | Out-Null }
        }
    }
    catch { Write-Verbose "Get-EnrollACEPrincipals: $_" }
    return ($enrollees | Select-Object -Unique)
}

function Get-WriteACEPrincipals {
    param([System.DirectoryServices.SearchResult]$SearchResult)
    $results = [System.Collections.Generic.List[PSObject]]::new()
    try {
        $de = $SearchResult.GetDirectoryEntry()
        $acl = $de.ObjectSecurity
        foreach ($ace in $acl.Access) {
            if ($ace.AccessControlType -ne 'Allow') { continue }
            $sid = $ace.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier])
            $sidStr = $sid.Value
            if (Test-IsPrivilegedSID -SID $sidStr) { continue }
            if ($ace.ActiveDirectoryRights -band $script:WriteRights) {
                $results.Add([PSCustomObject]@{
                    Principal = Resolve-SIDToName -SID $sid
                    SID       = $sidStr
                    Rights    = $ace.ActiveDirectoryRights.ToString()
                }) | Out-Null
            }
        }
    }
    catch { Write-Verbose "Get-WriteACEPrincipals: $_" }
    return $results
}
#endregion

#region ESC checks
function Invoke-ESC1Check { param([string]$ConfigNC)
    $findings = [System.Collections.Generic.List[object]]::new()
    $base = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"
    $authEKUFilter =
        "(pKIExtendedKeyUsage=$($script:EKU.ClientAuthentication))" +
        "(pKIExtendedKeyUsage=$($script:EKU.PKINITClientAuth))" +
        "(pKIExtendedKeyUsage=$($script:EKU.SmartCardLogon))" +
        "(pKIExtendedKeyUsage=$($script:EKU.AnyPurpose))" +
        "(!(pKIExtendedKeyUsage=*))"
    $filter = "(&" +
        "(objectClass=pKICertificateTemplate)" +
        "(!(flags:$($script:LDAP_MATCHING_RULE_BIT_AND):=2))" +
        "(!(msPKI-Enrollment-Flag:$($script:LDAP_MATCHING_RULE_BIT_AND):=2))" +
        "(msPKI-RA-Signature=0)" +
        "(msPKI-Certificate-Name-Flag:$($script:LDAP_MATCHING_RULE_BIT_AND):=1)" +
        "(|$authEKUFilter)" +
        ")"
    $props = @('name','msPKI-Certificate-Name-Flag','msPKI-Enrollment-Flag','msPKI-RA-Signature','pKIExtendedKeyUsage','msPKI-Template-Schema-Version','distinguishedName')
    $searcher = New-ADSISearcher -SearchBase $base -Filter $filter -Properties $props -ReadACL
    $results = $searcher.FindAll()
    try {
        foreach ($r in $results) {
            $name = Get-Prop $r 'name'
            $nameFlag = [long](Get-Prop $r 'msPKI-Certificate-Name-Flag')
            $ekus = Get-MultiProp $r 'pKIExtendedKeyUsage'
            $enrollees = Get-EnrollACEPrincipals -SearchResult $r
            if ($enrollees.Count -eq 0) { continue }
            $findings.Add((New-AdcsFindingObject -CheckID 'ESC1' -Severity 'Critical' `
                -Title "Enrollee-Supplied SAN in template: $name" `
                -Description (
                    "Template '$name' has CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT (0x{0:X8}). No manager approval, no authorized signatures. EKU: $(Get-FriendlyEKUList $ekus). Enrollees: $($enrollees -join ', ')." -f $nameFlag
                ) `
                -AffectedObjects @($name) `
                -Remediation "Remove EnrolleeSuppliesSubject; enable Manager Approval; restrict enrollment ACL." `
                -RawData @{ TemplateDN = Get-Prop $r 'distinguishedName'; NameFlag = $nameFlag; Enrollees = $enrollees })) | Out-Null
        }
    }
    finally { $results.Dispose() }
    return @($findings)
}

function Invoke-ESC2Check { param([string]$ConfigNC)
    $findings = [System.Collections.Generic.List[object]]::new()
    $base = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"
    $filter = "(&" +
        "(objectClass=pKICertificateTemplate)" +
        "(!(flags:$($script:LDAP_MATCHING_RULE_BIT_AND):=2))" +
        "(!(msPKI-Enrollment-Flag:$($script:LDAP_MATCHING_RULE_BIT_AND):=2))" +
        "(msPKI-RA-Signature=0)" +
        "(|(pKIExtendedKeyUsage=$($script:EKU.AnyPurpose))(!(pKIExtendedKeyUsage=*)))" +
        ")"
    $props = @('name','pKIExtendedKeyUsage','msPKI-Enrollment-Flag','msPKI-RA-Signature','msPKI-Certificate-Name-Flag','distinguishedName')
    $searcher = New-ADSISearcher -SearchBase $base -Filter $filter -Properties $props -ReadACL
    $results = $searcher.FindAll()
    try {
        foreach ($r in $results) {
            $name = Get-Prop $r 'name'
            $ekus = Get-MultiProp $r 'pKIExtendedKeyUsage'
            $enrollees = Get-EnrollACEPrincipals -SearchResult $r
            if ($enrollees.Count -eq 0) { continue }
            $findings.Add((New-AdcsFindingObject -CheckID 'ESC2' -Severity 'Critical' `
                -Title "Any Purpose / No EKU in template: $name" `
                -Description "Template '$name' EKU: [$(Get-FriendlyEKUList $ekus)]. Non-privileged enrollees: $($enrollees -join ', ')." `
                -AffectedObjects @($name) `
                -Remediation "Restrict EKU; remove Any Purpose; enable Manager Approval." `
                -RawData @{ TemplateDN = Get-Prop $r 'distinguishedName'; EKUs = $ekus; Enrollees = $enrollees })) | Out-Null
        }
    }
    finally { $results.Dispose() }
    return @($findings)
}

function Invoke-ESC3Check { param([string]$ConfigNC)
    $findings = [System.Collections.Generic.List[object]]::new()
    $base = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"
    $props = @('name','pKIExtendedKeyUsage','msPKI-Enrollment-Flag','msPKI-RA-Signature','msPKI-RA-Application-Policies','msPKI-Template-Schema-Version','distinguishedName')

    $filterCRA = "(&" +
        "(objectClass=pKICertificateTemplate)" +
        "(!(flags:$($script:LDAP_MATCHING_RULE_BIT_AND):=2))" +
        "(!(msPKI-Enrollment-Flag:$($script:LDAP_MATCHING_RULE_BIT_AND):=2))" +
        "(msPKI-RA-Signature=0)" +
        "(pKIExtendedKeyUsage=$($script:EKU.CertRequestAgent))" +
        ")"
    $s1 = New-ADSISearcher -SearchBase $base -Filter $filterCRA -Properties $props -ReadACL
    $r1 = $s1.FindAll()
    try {
        foreach ($r in $r1) {
            $name = Get-Prop $r 'name'
            $enrollees = Get-EnrollACEPrincipals -SearchResult $r
            if ($enrollees.Count -eq 0) { continue }
            $findings.Add((New-AdcsFindingObject -CheckID 'ESC3-CRA' -Severity 'High' `
                -Title "CertRequestAgent EKU enrollable: $name" `
                -Description "Template '$name' grants CertificateRequestAgent EKU. Enrollees: $($enrollees -join ', ')." `
                -AffectedObjects @($name) `
                -Remediation "Remove CRA EKU if not required; enable Manager Approval; restrict enrollment." `
                -RawData @{ TemplateDN = Get-Prop $r 'distinguishedName'; Enrollees = $enrollees })) | Out-Null
        }
    }
    finally { $r1.Dispose() }

    $authEKUFilter =
        "(pKIExtendedKeyUsage=$($script:EKU.ClientAuthentication))" +
        "(pKIExtendedKeyUsage=$($script:EKU.PKINITClientAuth))" +
        "(pKIExtendedKeyUsage=$($script:EKU.SmartCardLogon))" +
        "(pKIExtendedKeyUsage=$($script:EKU.AnyPurpose))" +
        "(!(pKIExtendedKeyUsage=*))"
    $filterAgent = "(&" +
        "(objectClass=pKICertificateTemplate)" +
        "(!(flags:$($script:LDAP_MATCHING_RULE_BIT_AND):=2))" +
        "(!(msPKI-Enrollment-Flag:$($script:LDAP_MATCHING_RULE_BIT_AND):=2))" +
        "(msPKI-RA-Application-Policies=$($script:EKU.CertRequestAgent))" +
        "(|$authEKUFilter)" +
        ")"
    $s2 = New-ADSISearcher -SearchBase $base -Filter $filterAgent -Properties $props -ReadACL
    $r2 = $s2.FindAll()
    try {
        foreach ($r in $r2) {
            $name = Get-Prop $r 'name'
            $enrollees = Get-EnrollACEPrincipals -SearchResult $r
            $raPolicies = Get-MultiProp $r 'msPKI-RA-Application-Policies'
            $findings.Add((New-AdcsFindingObject -CheckID 'ESC3-Agent' -Severity 'High' `
                -Title "Template accepts CRA-signed enrollment: $name" `
                -Description "msPKI-RA-Application-Policies includes CRA. RA policies: $($raPolicies -join ', '). Enrollees: $($enrollees -join ', ')." `
                -AffectedObjects @($name) `
                -Remediation "Review RA policies; enable Manager Approval; revoke unnecessary EA certs." `
                -RawData @{ TemplateDN = Get-Prop $r 'distinguishedName'; RAPolicies = $raPolicies })) | Out-Null
        }
    }
    finally { $r2.Dispose() }
    return @($findings)
}

function Invoke-ESC4Check { param([string]$ConfigNC)
    if ($script:SkipACLChecks) { return @() }
    $findings = [System.Collections.Generic.List[object]]::new()
    $base = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigNC"
    $filter = "(&(objectClass=pKICertificateTemplate)(!(flags:$($script:LDAP_MATCHING_RULE_BIT_AND):=2)))"
    $props = @('name','distinguishedName','flags')
    $searcher = New-ADSISearcher -SearchBase $base -Filter $filter -Properties $props -ReadACL
    $results = $searcher.FindAll()
    try {
        foreach ($r in $results) {
            $name = Get-Prop $r 'name'
            $writeACEs = Get-WriteACEPrincipals -SearchResult $r
            if ($writeACEs.Count -eq 0) { continue }
            $aceDetails = $writeACEs | ForEach-Object { "$($_.Principal) [$($_.Rights)]" }
            $findings.Add((New-AdcsFindingObject -CheckID 'ESC4' -Severity 'High' `
                -Title "Non-admin write rights on template: $name" `
                -Description "Template '$name' writable by non-admin principals. ACEs:`n  $($aceDetails -join "`n  ")" `
                -AffectedObjects @($name) `
                -Remediation "Remove excessive write rights; only CA/DA should manage templates." `
                -RawData @{ TemplateDN = Get-Prop $r 'distinguishedName'; WriteACEs = $writeACEs })) | Out-Null
        }
    }
    finally { $results.Dispose() }
    return @($findings)
}

function Invoke-ESC5Check { param([string]$ConfigNC)
    if ($script:SkipACLChecks) { return @() }
    $findings = [System.Collections.Generic.List[object]]::new()
    $pkiBase = "CN=Public Key Services,CN=Services,$ConfigNC"
    $criticalDNs = @{
        'NTAuthCertificates'  = "CN=NTAuthCertificates,$pkiBase"
        'EnrollmentServices'  = "CN=Enrollment Services,$pkiBase"
        'AIA Container'       = "CN=AIA,$pkiBase"
        'CDP Container'       = "CN=CDP,$pkiBase"
        'OID Container'       = "CN=OID,$pkiBase"
        'PKI Services Root'   = $pkiBase
        'Templates Container' = "CN=Certificate Templates,$pkiBase"
    }
    foreach ($objName in $criticalDNs.Keys) {
        $dn = $criticalDNs[$objName]
        try {
            $s = New-ADSISearcher -SearchBase $dn -Filter '(objectClass=*)' -Properties @('name','distinguishedName') -Scope 'Base' -ReadACL
            $one = $s.FindOne()
            if (-not $one) { continue }
            $writeACEs = Get-WriteACEPrincipals -SearchResult $one
            if ($writeACEs.Count -gt 0) {
                $aceDetails = $writeACEs | ForEach-Object { "$($_.Principal) [$($_.Rights)]" }
                $findings.Add((New-AdcsFindingObject -CheckID 'ESC5' -Severity 'Critical' `
                    -Title "Non-admin write rights on PKI object: $objName" `
                    -Description "Object '$objName' ($dn). ACEs:`n  $($aceDetails -join "`n  ")" `
                    -AffectedObjects @($dn) `
                    -Remediation "Remove non-admin write rights from critical PKI containers; enable auditing." `
                    -RawData @{ DN = $dn; WriteACEs = $writeACEs })) | Out-Null
            }
        }
        catch { Write-Verbose "ESC5 $objName : $_" }
    }
    return @($findings)
}

function Invoke-ESC6Check { param([string]$ConfigNC)
    $findings = [System.Collections.Generic.List[object]]::new()
    $base = "CN=Enrollment Services,CN=Public Key Services,CN=Services,$ConfigNC"
    $props = @('name','dNSHostName','distinguishedName')
    $searcher = New-ADSISearcher -SearchBase $base -Filter '(objectClass=pKIEnrollmentService)' -Properties $props
    $results = $searcher.FindAll()
    try {
        if ($script:SkipNetworkProbes -and $results.Count -gt 0) {
            $findings.Add((New-AdcsFindingObject -CheckID 'ESC6' -Severity 'Info' `
                -Title 'ESC6: certutil EditFlags probe skipped (-AdcsSkipNetworkProbes)' `
                -Description "EDITF_ATTRIBUTESUBJECTALTNAME2 was not read via certutil for $($results.Count) enterprise CA object(s). Re-run without -AdcsSkipNetworkProbes from a host with RPC access to the issuing CA, or run certutil -getreg policy\EditFlags on the CA." `
                -AffectedObjects @('Enterprise CA') `
                -Remediation 'Omit -AdcsSkipNetworkProbes for automated ESC6, or validate EditFlags on each CA host.')) | Out-Null
        }
        foreach ($r in $results) {
            if ($script:SkipNetworkProbes) { continue }
            $caName = Get-Prop $r 'name'
            $dnsName = Get-Prop $r 'dNSHostName'
            $flagDetected = $null
            try {
                $configStr = "$dnsName\$caName"
                $raw = & certutil.exe -config $configStr -getreg "policy\EditFlags" 2>$null
                if ($raw) {
                    $hexMatch = $raw | Select-String 'EditFlags\s+REG_DWORD\s+=\s+0x([0-9a-fA-F]+)'
                    $namedMatch = $raw | Select-String 'EDITF_ATTRIBUTESUBJECTALTNAME2'
                    if ($namedMatch) { $flagDetected = $true }
                    elseif ($hexMatch) {
                        $hexVal = [Convert]::ToInt64($hexMatch.Matches[0].Groups[1].Value, 16)
                        $flagDetected = (Test-Bit -Value $hexVal -Bit $script:EDITF_ATTRIBUTESUBJECTALTNAME2)
                    }
                }
            }
            catch { Write-Verbose "certutil ESC6 $caName : $_" }
            if ($flagDetected -eq $true) {
                $findings.Add((New-AdcsFindingObject -CheckID 'ESC6' -Severity 'Critical' `
                    -Title "EDITF_ATTRIBUTESUBJECTALTNAME2 on CA: $caName" `
                    -Description "CA '$caName' ($dnsName) has EDITF_ATTRIBUTESUBJECTALTNAME2 enabled." `
                    -AffectedObjects @($caName, $dnsName) `
                    -Remediation "Disable flag via certutil -setreg; restart certsvc; apply KB5014754." `
                    -RawData @{ CAName = $caName; DNSName = $dnsName })) | Out-Null
            }
            elseif ($flagDetected -eq $null -and -not $script:SkipNetworkProbes) {
                $findings.Add((New-AdcsFindingObject -CheckID 'ESC6' -Severity 'Info' `
                    -Title "ESC6 manual check: $caName" `
                    -Description "Could not read EditFlags for '$caName' ($dnsName) via certutil." `
                    -AffectedObjects @($caName) `
                    -Remediation "Run certutil -config '$dnsName\$caName' -getreg policy\EditFlags on a host with CA access." `
                    -RawData @{})) | Out-Null
            }
        }
    }
    finally { $results.Dispose() }
    return @($findings)
}

function Invoke-ESC7Check { param([string]$ConfigNC)
    if ($script:SkipACLChecks) { return @() }
    $findings = [System.Collections.Generic.List[object]]::new()
    $base = "CN=Enrollment Services,CN=Public Key Services,CN=Services,$ConfigNC"
    $props = @('name','dNSHostName','distinguishedName')
    $searcher = New-ADSISearcher -SearchBase $base -Filter '(objectClass=pKIEnrollmentService)' -Properties $props -ReadACL
    $results = $searcher.FindAll()
    try {
        foreach ($r in $results) {
            $caName = Get-Prop $r 'name'
            $dnsName = Get-Prop $r 'dNSHostName'
            $writeACEs = Get-WriteACEPrincipals -SearchResult $r
            if ($writeACEs.Count -eq 0) { continue }
            $aceDetails = $writeACEs | ForEach-Object { "$($_.Principal) [$($_.Rights)]" }
            $findings.Add((New-AdcsFindingObject -CheckID 'ESC7' -Severity 'High' `
                -Title "Non-admin write on CA object: $caName" `
                -Description "CA '$caName' ($dnsName). Elevated AD permissions for non-admins. ACEs:`n  $($aceDetails -join "`n  ")" `
                -AffectedObjects @($caName, $dnsName) `
                -Remediation "Restrict CA object permissions; review certsrv.msc Security tab." `
                -RawData @{ CAName = $caName; DNSName = $dnsName; WriteACEs = $writeACEs })) | Out-Null
        }
    }
    finally { $results.Dispose() }
    return @($findings)
}

function Invoke-ESC8Check { param([string]$ConfigNC)
    $findings = [System.Collections.Generic.List[object]]::new()
    $base = "CN=Enrollment Services,CN=Public Key Services,CN=Services,$ConfigNC"
    $props = @('name','dNSHostName','msPKI-Enrollment-Servers','flags','distinguishedName')
    $searcher = New-ADSISearcher -SearchBase $base -Filter '(objectClass=pKIEnrollmentService)' -Properties $props
    $results = $searcher.FindAll()
    try {
        foreach ($r in $results) {
            $caName = Get-Prop $r 'name'
            $dnsName = Get-Prop $r 'dNSHostName'
            $enrollServers = Get-MultiProp $r 'msPKI-Enrollment-Servers'
            $httpEndpoints = @()
            $httpsEndpoints = @()
            foreach ($entry in $enrollServers) {
                $entryStr = $entry.ToString()
                if ($entryStr -match '^https?://') {
                    if ($entryStr -match '^http://') { $httpEndpoints += $entryStr }
                    else { $httpsEndpoints += $entryStr }
                }
            }
            $probeHttp = $false
            $probeHttps = $false
            if (-not $script:SkipNetworkProbes -and $dnsName) {
                foreach ($scheme in @('http','https')) {
                    try {
                        $req = [System.Net.HttpWebRequest]::Create("${scheme}://${dnsName}/certsrv/")
                        $req.Timeout = 4000
                        $req.Method = 'HEAD'
                        $req.AllowAutoRedirect = $false
                        $req.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                        try {
                            $resp = $req.GetResponse()
                            $code = [int]$resp.StatusCode
                            $resp.Close()
                            if ($code -in @(200, 301, 302)) {
                                if ($scheme -eq 'http') { $probeHttp = $true } else { $probeHttps = $true }
                            }
                        }
                        catch [System.Net.WebException] {
                            if ($_.Exception.Response) {
                                $status = [int]$_.Exception.Response.StatusCode
                                if ($status -in @(200, 301, 302, 401)) {
                                    if ($scheme -eq 'http') { $probeHttp = $true } else { $probeHttps = $true }
                                }
                            }
                        }
                    }
                    catch { Write-Verbose "ESC8 probe ${scheme}://${dnsName}: $_" }
                }
            }
            $hasHttpLDAP = $httpEndpoints.Count -gt 0
            $hasHttpProbe = $probeHttp
            if ($hasHttpLDAP -or $hasHttpProbe) {
                $endpointInfo = if ($hasHttpLDAP) { "HTTP in LDAP: $($httpEndpoints -join ', ')" } else { "HTTP probe: http://${dnsName}/certsrv/" }
                $findings.Add((New-AdcsFindingObject -CheckID 'ESC8' -Severity 'Critical' `
                    -Title "Web Enrollment over HTTP: $caName" `
                    -Description "CA '$caName' ($dnsName). $endpointInfo HTTPS probe: $probeHttps" `
                    -AffectedObjects @($caName, "http://$dnsName/certsrv") `
                    -Remediation "Require HTTPS; enable EPA; disable Web Enrollment if unused (KB5005413)." `
                    -RawData @{ CAName = $caName; DNSName = $dnsName; HTTPEndpoints = $httpEndpoints })) | Out-Null
            }
            elseif ($httpsEndpoints.Count -gt 0 -or $probeHttps) {
                $findings.Add((New-AdcsFindingObject -CheckID 'ESC8' -Severity 'Medium' `
                    -Title ('Web Enrollment HTTPS - verify EPA: ' + $caName) `
                    -Description ('HTTPS only. Endpoints: ' + ($httpsEndpoints -join ', ') + '. Verify EPA on IIS certsrv.') `
                    -AffectedObjects @($caName) `
                    -Remediation 'Enable EPA for certsrv in IIS.' `
                    -RawData @{})) | Out-Null
            }
        }
        if ($script:SkipNetworkProbes -and $results.Count -gt 0) {
            $findings.Add((New-AdcsFindingObject -CheckID 'ESC8' -Severity 'Info' `
                -Title 'ESC8: Optional HTTP(S) probes skipped (-AdcsSkipNetworkProbes)' `
                -Description 'Remote HEAD requests to http(s)://<CA>/certsrv/ were not executed. msPKI-Enrollment-Servers values from LDAP are still evaluated; relay/NTLM exposure may be understated without network probes.' `
                -AffectedObjects @('Web Enrollment') `
                -Remediation 'Re-run without -AdcsSkipNetworkProbes from a host that can reach CA web endpoints, or test manually per KB5005413.')) | Out-Null
        }
    }
    finally { $results.Dispose() }
    return @($findings)
}

function Invoke-AdcsEscByName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('ESC1','ESC2','ESC3','ESC4','ESC5','ESC6','ESC7','ESC8')][string]$Name,
        [Parameter(Mandatory)][string]$ConfigurationNamingContext
    )
    switch ($Name) {
        'ESC1' { return Invoke-ESC1Check -ConfigNC $ConfigurationNamingContext }
        'ESC2' { return Invoke-ESC2Check -ConfigNC $ConfigurationNamingContext }
        'ESC3' { return Invoke-ESC3Check -ConfigNC $ConfigurationNamingContext }
        'ESC4' { return Invoke-ESC4Check -ConfigNC $ConfigurationNamingContext }
        'ESC5' { return Invoke-ESC5Check -ConfigNC $ConfigurationNamingContext }
        'ESC6' { return Invoke-ESC6Check -ConfigNC $ConfigurationNamingContext }
        'ESC7' { return Invoke-ESC7Check -ConfigNC $ConfigurationNamingContext }
        'ESC8' { return Invoke-ESC8Check -ConfigNC $ConfigurationNamingContext }
    }
    return @()
}
#endregion

Export-ModuleMember -Function @(
    'Set-ADSuiteAdcsSession',
    'Invoke-AdcsEscByName',
    'Invoke-ESC1Check','Invoke-ESC2Check','Invoke-ESC3Check','Invoke-ESC4Check',
    'Invoke-ESC5Check','Invoke-ESC6Check','Invoke-ESC7Check','Invoke-ESC8Check'
)

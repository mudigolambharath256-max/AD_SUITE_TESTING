# ============================================================
# CHECK: DCONF-007_NTLMv1_Protocol_Allowed
# CATEGORY: Domain_Configuration
# DESCRIPTION: Checks if NTLMv1 authentication is allowed (security risk)
# LDAP FILTER: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
# SEARCH BASE: Default NC
# OBJECT CLASS: computer
# ATTRIBUTES: name, dNSHostName, distinguishedName
# RISK: HIGH
# MITRE ATT&CK: T1557.001 (LLMNR/NBT-NS Poisoning and SMB Relay)
# ============================================================

# Combined Multi-Engine Implementation with Fallback Chain
# ─────────────────────────────────────────────────────────
# Engine Priority: ActiveDirectory → ADSI → .NET → CMD
# ─────────────────────────────────────────────────────────

param(
    [string]$Engine = "AUTO"
)

function Test-ActiveDirectoryModule {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Invoke-PowerShellEngine {
    Write-Host "[ENGINE] Using PowerShell ActiveDirectory module" -ForegroundColor Green

    try {
        $domainControllers = Get-ADDomainController -Filter *
        $findings = @()

        foreach ($dc in $domainControllers) {
            try {
                $scriptBlock = {
                    try {
                        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
                        $regValue = Get-ItemProperty -Path $regPath -Name "LmCompatibilityLevel" -ErrorAction SilentlyContinue
                        if ($regValue) { $regValue.LmCompatibilityLevel } else { 0 }
                    } catch { 0 }
                }

                $lmLevel = Invoke-Command -ComputerName $dc.HostName -ScriptBlock $scriptBlock -ErrorAction SilentlyContinue
                if ($null -eq $lmLevel) { $lmLevel = 0 }

                if ($lmLevel -lt 5) {
                    $levelDescription = switch ($lmLevel) {
                        0 { "Send LM and NTLM responses (CRITICAL)" }
                        1 { "Send LM and NTLM with NTLMv2 session security (HIGH)" }
                        2 { "Send NTLM response only (HIGH)" }
                        3 { "Send NTLMv2 response only (MEDIUM)" }
                        4 { "Send NTLMv2 response only, refuse LM (MEDIUM)" }
                        default { "Unknown level $lmLevel" }
                    }

                    $severity = if ($lmLevel -le 2) { "CRITICAL" } elseif ($lmLevel -le 4) { "HIGH" } else { "MEDIUM" }

                    $findings += [PSCustomObject]@{
                        CheckID = 'DCONF-007'
                        CheckName = 'NTLMv1 Protocol Allowed'
                        Domain = $dc.Domain
                        ObjectDN = $dc.ComputerObjectDN
                        ObjectName = $dc.HostName
                        FindingDetail = "LmCompatibilityLevel: $lmLevel - $levelDescription"
                        Severity = $severity
                        Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                    }
                }
            } catch {
                Write-Warning "Failed to check $($dc.HostName): $_"
            }
        }

        return $findings
    } catch {
        throw "PowerShell engine failed: $_"
    }
}

function Invoke-ADSIEngine {
    Write-Host "[ENGINE] Using ADSI DirectorySearcher" -ForegroundColor Yellow

    try {
        $searcher = [ADSISearcher]'(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
        $searcher.PropertiesToLoad.Clear()
        @('name', 'dNSHostName', 'distinguishedName') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

        $dcResults = $searcher.FindAll()
        $findings = @()

        foreach ($dcResult in $dcResults) {
            $dcProps = $dcResult.Properties
            $dcName = if ($dcProps['dnshostname'] -and $dcProps['dnshostname'].Count -gt 0) { $dcProps['dnshostname'][0] } else { $dcProps['name'][0] }

            try {
                $regQuery = Get-WmiObject -ComputerName $dcName -Class Win32_Registry -ErrorAction SilentlyContinue
                if ($regQuery) {
                    $hklm = 2147483650
                    $keyPath = "SYSTEM\CurrentControlSet\Control\Lsa"
                    $valueName = "LmCompatibilityLevel"

                    $regValue = $regQuery.GetDWORDValue($hklm, $keyPath, $valueName)
                    $lmLevel = if ($regValue.ReturnValue -eq 0) { $regValue.uValue } else { 0 }

                    if ($lmLevel -lt 5) {
                        $levelDescription = switch ($lmLevel) {
                            0 { "Send LM and NTLM responses (CRITICAL)" }
                            1 { "Send LM and NTLM with NTLMv2 session security (HIGH)" }
                            2 { "Send NTLM response only (HIGH)" }
                            3 { "Send NTLMv2 response only (MEDIUM)" }
                            4 { "Send NTLMv2 response only, refuse LM (MEDIUM)" }
                            default { "Unknown level $lmLevel" }
                        }

                        $severity = if ($lmLevel -le 2) { "CRITICAL" } elseif ($lmLevel -le 4) { "HIGH" } else { "MEDIUM" }

                        $findings += [PSCustomObject]@{
                            CheckID = 'DCONF-007'
                            CheckName = 'NTLMv1 Protocol Allowed'
                            Domain = $dcName.Split('.')[1..99] -join '.'
                            ObjectDN = if ($dcProps['distinguishedname'] -and $dcProps['distinguishedname'].Count -gt 0) { $dcProps['distinguishedname'][0] } else { 'N/A' }
                            ObjectName = $dcName
                            FindingDetail = "LmCompatibilityLevel: $lmLevel - $levelDescription"
                            Severity = $severity
                            Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                        }
                    }
                }
            } catch {
                Write-Warning "Failed to check $dcName"
            }
        }

        $dcResults.Dispose()
        $searcher.Dispose()
        return $findings
    } catch {
        throw "ADSI engine failed: $_"
    }
}

function Invoke-CMDEngine {
    Write-Host "[ENGINE] Using CMD/dsquery fallback" -ForegroundColor Red
    Write-Warning "CMD engine has limited NTLMv1 detection capability"
    return @()
}

# Main execution logic
try {
    $results = @()

    switch ($Engine.ToUpper()) {
        "PS" { $results = Invoke-PowerShellEngine }
        "ADSI" { $results = Invoke-ADSIEngine }
        "CMD" { $results = Invoke-CMDEngine }
        "AUTO" {
            try {
                if (Test-ActiveDirectoryModule) {
                    $results = Invoke-PowerShellEngine
                } else {
                    $results = Invoke-ADSIEngine
                }
            } catch {
                Write-Warning "Primary engines failed: $_"
                $results = Invoke-CMDEngine
            }
        }
        default { throw "Invalid engine specified: $Engine" }
    }

    if ($results -and $results.Count -gt 0) {
        Write-Host "Found $($results.Count) DCs with NTLMv1 allowed" -ForegroundColor Yellow
        $results | Format-List
    } else {
        Write-Host "No findings - all DCs have NTLMv2-only configuration" -ForegroundColor Green
    }

} catch {
    Write-Error "Check execution failed: $_"
    exit 1
}

# ── BloodHound Export ─────────────────────────────────────────────────────────
# Added by Kiro automation — DO NOT modify lines above this section
try {
    $bhSession = if ($env:ADSUITE_SESSION_ID) { $env:ADSUITE_SESSION_ID } else { [guid]::NewGuid().ToString('N') }
    $bhRoot    = if ($env:ADSUITE_OUTPUT_ROOT) { $env:ADSUITE_OUTPUT_ROOT } else { Join-Path $env:TEMP 'ADSuite_Sessions' }
    $bhDir     = Join-Path $bhRoot "$bhSession\bloodhound"
    if (-not (Test-Path $bhDir)) { New-Item -ItemType Directory -Path $bhDir -Force -ErrorAction Stop | Out-Null }

    $bhNodes = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($r in $uniqueResults) {
        $dn   = if ($r.DistinguishedName) { $r.DistinguishedName } else { '' }
        $name = if ($r.Name) { $r.Name } else { if ($r.PSObject.Properties['CheckName']) { $r.CheckName } else { 'UNKNOWN' } }
        $dom  = (($dn -split ',') | Where-Object{$_ -match '^DC='} | ForEach-Object{$_ -replace '^DC=',''}) -join '.' | ForEach-Object{$_.ToUpper()}
        $oid  = if ($dn) { $dn.ToUpper() } else { [guid]::NewGuid().ToString() }

        $bhNodes.Add(@{
            ObjectIdentifier = $oid
            Properties       = @{
                name              = if ($dom) { "$($name.ToUpper())@$dom" } else { $name.ToUpper() }
                domain            = $dom
                distinguishedname = $dn.ToUpper()
                enabled           = $true
                adSuiteCheckId    = 'DCONF-007'
                adSuiteCheckName  = 'NTLMv1_Protocol_Allowed'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteDomain_Configuration   = 'Domain_Configuration'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "DCONF-007_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

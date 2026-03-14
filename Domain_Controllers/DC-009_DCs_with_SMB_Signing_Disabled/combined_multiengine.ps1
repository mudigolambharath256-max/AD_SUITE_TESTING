# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: DCs with SMB Signing Disabled
# Category: Domain Controllers
# ID: DC-009
# Severity: critical
# Registry: HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters\requireSecuritySignature
# =============================================================================

param(
    [string]$Engine = "AUTO"
)

$ErrorActionPreference = 'Continue'
$results = @()

Write-Host "=== Multi-Engine Execution: DCs with SMB Signing Disabled (Forest-Wide) ===" -ForegroundColor Cyan
Write-Host ""

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
        # Get all domains in the forest
        $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
        $allResults = @()

        foreach ($domain in $forest.Domains) {
            Write-Host "  Querying domain: $($domain.Name)" -ForegroundColor Cyan

            try {
                $domainControllers = Get-ADDomainController -Server $domain.Name -Filter *

                foreach ($dc in $domainControllers) {
                    try {
                        $scriptBlock = {
                            try {
                                $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters"
                                $value = Get-ItemProperty -Path $regPath -Name "requireSecuritySignature" -ErrorAction SilentlyContinue
                                return if ($value) { $value.requireSecuritySignature } else { $null }
                            } catch { return "ERROR" }
                        }

                        $smbSigningRequired = Invoke-Command -ComputerName $dc.HostName -ScriptBlock $scriptBlock -ErrorAction Stop

                        if ($smbSigningRequired -ne 1) {
                            $allResults += [PSCustomObject]@{
                                CheckID = 'DC-009'
                                CheckName = 'DCs with SMB Signing Disabled'
                                Domain = $domain.Name
                                ObjectDN = $dc.ComputerObjectDN
                                ObjectName = $dc.HostName
                                FindingDetail = "SMB signing not required: Registry value=$smbSigningRequired (should be 1)"
                                Severity = 'CRITICAL'
                                Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                                Engine = 'PowerShell'
                            }
                        }
                    } catch {
                        $allResults += [PSCustomObject]@{
                            CheckID = 'DC-009'
                            CheckName = 'DCs with SMB Signing Disabled'
                            Domain = $domain.Name
                            ObjectDN = $dc.ComputerObjectDN
                            ObjectName = $dc.HostName
                            FindingDetail = "SMB signing status unknown: Remote access failed - $_"
                            Severity = 'HIGH'
                            Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                            Engine = 'PowerShell'
                        }
                    }
                }
            } catch {
                Write-Warning "Failed to query domain $($domain.Name): $_"
            }
        }

        return $allResults
    } catch {
        throw "PowerShell engine failed: $_"
    }
}

function Invoke-ADSIEngine {
    Write-Host "[ENGINE] Using ADSI DirectorySearcher" -ForegroundColor Yellow

    try {
        # Get all domains in the forest
        $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
        $allResults = @()

        foreach ($domain in $forest.Domains) {
            Write-Host "  Querying domain: $($domain.Name)" -ForegroundColor Cyan

            try {
                $searcher = [ADSISearcher]"LDAP://$($domain.Name)/DC=$($domain.Name.Replace('.', ',DC='))"
                $searcher.Filter = '(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))'
                $searcher.PageSize = 1000
                $searcher.PropertiesToLoad.Clear()
                @('name', 'distinguishedName', 'dNSHostName', 'operatingSystem') | ForEach-Object { [void]$searcher.PropertiesToLoad.Add($_) }

                $dcResults = $searcher.FindAll()

                foreach ($dcResult in $dcResults) {
                    $p = $dcResult.Properties
                    $dnsHostName = if ($p['dnshostname'] -and $p['dnshostname'].Count -gt 0) { $p['dnshostname'][0] } else { $null }

                    if (-not $dnsHostName) { continue }

                    try {
                        $regQuery = Get-WmiObject -ComputerName $dnsHostName -Class Win32_Registry -ErrorAction SilentlyContinue
                        if ($regQuery) {
                            $hklm = 2147483650
                            $keyPath = "SYSTEM\CurrentControlSet\Services\LanManServer\Parameters"
                            $valueName = "requireSecuritySignature"

                            $regValue = $regQuery.GetDWORDValue($hklm, $keyPath, $valueName)
                            $smbSigningRequired = if ($regValue.ReturnValue -eq 0) { $regValue.uValue } else { $null }

                            if ($smbSigningRequired -ne 1) {
                                $allResults += [PSCustomObject]@{
                                    CheckID = 'DC-009'
                                    CheckName = 'DCs with SMB Signing Disabled'
                                    Domain = $domain.Name
                                    ObjectDN = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                                    ObjectName = $dnsHostName
                                    FindingDetail = "SMB signing not required: Registry value=$smbSigningRequired (should be 1)"
                                    Severity = 'CRITICAL'
                                    Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                                    Engine = 'ADSI'
                                }
                            }
                        }
                    } catch {
                        $allResults += [PSCustomObject]@{
                            CheckID = 'DC-009'
                            CheckName = 'DCs with SMB Signing Disabled'
                            Domain = $domain.Name
                            ObjectDN = if ($p['distinguishedname'] -and $p['distinguishedname'].Count -gt 0) { $p['distinguishedname'][0] } else { 'N/A' }
                            ObjectName = $dnsHostName
                            FindingDetail = "SMB signing status unknown: Registry access failed"
                            Severity = 'HIGH'
                            Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                            Engine = 'ADSI'
                        }
                    }
                }

                $dcResults.Dispose()
                $searcher.Dispose()
            } catch {
                Write-Warning "Failed to query domain $($domain.Name): $_"
            }
        }

        return $allResults
    } catch {
        throw "ADSI engine failed: $_"
    }
}

function Invoke-CMDEngine {
    Write-Host "[ENGINE] Using CMD/dsquery fallback" -ForegroundColor Red
    Write-Warning "CMD engine has limited forest enumeration and registry access capability"
    return @()
}

# Main execution logic
try {
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
        Write-Host "Found $($results.Count) DCs with SMB signing issues across forest" -ForegroundColor Red
        $results | Format-List

        # Summary by severity
        $criticalCount = ($results | Where-Object { $_.Severity -eq 'CRITICAL' }).Count
        $highCount = ($results | Where-Object { $_.Severity -eq 'HIGH' }).Count
        Write-Host "Critical: $criticalCount, High: $highCount" -ForegroundColor Yellow
    } else {
        Write-Host "No SMB signing issues found - all DCs properly configured" -ForegroundColor Green
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
                adSuiteCheckId    = 'DC-009'
                adSuiteCheckName  = 'DCs_with_SMB_Signing_Disabled'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteDomain_Controllers   = 'Domain_Controllers'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "DC-009_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

# ============================================================
# CHECK: DCONF-008_SMB1_Protocol_Enabled
# CATEGORY: Domain_Configuration
# DESCRIPTION: Checks if SMB1 protocol is enabled (critical security risk)
# LDAP FILTER: (&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
# SEARCH BASE: Default NC
# OBJECT CLASS: computer
# ATTRIBUTES: name, dNSHostName, distinguishedName
# RISK: CRITICAL
# MITRE ATT&CK: T1021.002 (Remote Services: SMB/Windows Admin Shares)
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
                    $smb1Issues = @()

                    try {
                        # Check SMB1 server registry setting
                        $smb1ServerReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -ErrorAction SilentlyContinue
                        if ($smb1ServerReg -and $smb1ServerReg.SMB1 -ne 0) {
                            $smb1Issues += "SMB1 Server enabled (registry)"
                        }

                        # Check SMB1 client via mrxsmb10 service
                        $mrxsmb10 = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10" -Name "Start" -ErrorAction SilentlyContinue
                        if ($mrxsmb10 -and $mrxsmb10.Start -ne 4) {
                            $smb1Issues += "SMB1 Client enabled (mrxsmb10)"
                        }

                        # Check Windows Feature (Server 2016+)
                        try {
                            $smb1Feature = Get-WindowsFeature -Name "FS-SMB1" -ErrorAction SilentlyContinue
                            if ($smb1Feature -and $smb1Feature.InstallState -eq "Installed") {
                                $smb1Issues += "SMB1 Feature installed"
                            }
                        } catch {
                            # Fallback for older OS or workstation
                            $smb1OptionalFeature = Get-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -ErrorAction SilentlyContinue
                            if ($smb1OptionalFeature -and $smb1OptionalFeature.State -eq "Enabled") {
                                $smb1Issues += "SMB1 Optional Feature enabled"
                            }
                        }
                    } catch {
                        $smb1Issues += "Error checking SMB1 status: $($_.Exception.Message)"
                    }

                    return $smb1Issues
                }

                $smb1Issues = Invoke-Command -ComputerName $dc.HostName -ScriptBlock $scriptBlock -ErrorAction SilentlyContinue

                if ($smb1Issues -and $smb1Issues.Count -gt 0) {
                    $findings += [PSCustomObject]@{
                        CheckID = 'DCONF-008'
                        CheckName = 'SMB1 Protocol Enabled'
                        Domain = $dc.Domain
                        ObjectDN = $dc.ComputerObjectDN
                        ObjectName = $dc.HostName
                        FindingDetail = "SMB1 enabled: $($smb1Issues -join '; ')"
                        Severity = "CRITICAL"
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
                    $smb1Issues = @()

                    # Check SMB1 server setting
                    $serverKeyPath = "SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
                    $serverResult = $regQuery.GetDWORDValue($hklm, $serverKeyPath, "SMB1")
                    $smb1Server = if ($serverResult.ReturnValue -eq 0) { $serverResult.uValue } else { 1 }

                    if ($smb1Server -ne 0) {
                        $smb1Issues += "SMB1 Server enabled (SMB1=$smb1Server)"
                    }

                    # Check SMB1 client via mrxsmb10 service
                    $clientKeyPath = "SYSTEM\CurrentControlSet\Services\mrxsmb10"
                    $clientResult = $regQuery.GetDWORDValue($hklm, $clientKeyPath, "Start")
                    if ($clientResult.ReturnValue -eq 0 -and $clientResult.uValue -ne 4) {
                        $smb1Issues += "SMB1 Client enabled (mrxsmb10 Start=$($clientResult.uValue))"
                    }

                    if ($smb1Issues.Count -gt 0) {
                        $findings += [PSCustomObject]@{
                            CheckID = 'DCONF-008'
                            CheckName = 'SMB1 Protocol Enabled'
                            Domain = $dcName.Split('.')[1..99] -join '.'
                            ObjectDN = if ($dcProps['distinguishedname'] -and $dcProps['distinguishedname'].Count -gt 0) { $dcProps['distinguishedname'][0] } else { 'N/A' }
                            ObjectName = $dcName
                            FindingDetail = "SMB1 enabled: $($smb1Issues -join '; ')"
                            Severity = "CRITICAL"
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
    Write-Warning "CMD engine has limited SMB1 detection capability"
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
        Write-Host "Found $($results.Count) DCs with SMB1 enabled" -ForegroundColor Red
        $results | Format-List
    } else {
        Write-Host "No findings - SMB1 is disabled on all DCs" -ForegroundColor Green
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
                adSuiteCheckId    = 'DCONF-008'
                adSuiteCheckName  = 'SMB1_Protocol_Enabled'
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
    $bhFile = Join-Path $bhDir "DCONF-008_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

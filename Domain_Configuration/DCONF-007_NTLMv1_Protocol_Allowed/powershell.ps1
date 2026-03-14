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

# PowerShell Active Directory Module Implementation
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : Registry via Invoke-Command
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
    Import-Module ActiveDirectory -ErrorAction Stop

    # Get all domain controllers
    $domainControllers = Get-ADDomainController -Filter *
    Write-Host "Found $($domainControllers.Count) domain controllers to check" -ForegroundColor Cyan

    $findings = @()

    foreach ($dc in $domainControllers) {
        try {
            # Check LmCompatibilityLevel registry setting
            $scriptBlock = {
                try {
                    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
                    $regValue = Get-ItemProperty -Path $regPath -Name "LmCompatibilityLevel" -ErrorAction SilentlyContinue
                    if ($regValue) { $regValue.LmCompatibilityLevel } else { 0 }
                } catch { 0 }
            }

            $lmLevel = Invoke-Command -ComputerName $dc.HostName -ScriptBlock $scriptBlock -ErrorAction SilentlyContinue
            if ($null -eq $lmLevel) { $lmLevel = 0 }  # Default if not set or unreachable

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
            Write-Warning "Failed to check NTLMv1 settings on $($dc.HostName): $_"
        }
    }

    if ($findings) {
        Write-Host "Found $($findings.Count) DCs with NTLMv1 allowed" -ForegroundColor Yellow
        $findings | Format-Table -AutoSize
    } else {
        Write-Host 'No findings - all DCs have NTLMv2-only configuration' -ForegroundColor Green
    }

} catch {
    Write-Error "Active Directory query failed: $_"
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

    foreach ($r in $output) {
        $dn   = if ($r.DistinguishedName) { $r.DistinguishedName } else { '' }
        $name = if ($r.Name) { $r.Name } else { 'UNKNOWN' }
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

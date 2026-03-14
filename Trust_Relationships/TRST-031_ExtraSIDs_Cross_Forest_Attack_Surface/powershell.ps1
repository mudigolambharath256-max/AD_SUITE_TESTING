# ============================================================
# CHECK: TRST-031_ExtraSIDs_Cross_Forest_Attack_Surface
# CATEGORY: Trust_Relationships
# DESCRIPTION: Detects forest trusts vulnerable to ExtraSIDs attacks
# LDAP FILTER: (&(objectClass=trustedDomain)(trustType=2))
# SEARCH BASE: CN=System,<DomainDN>
# OBJECT CLASS: trustedDomain
# ATTRIBUTES: trustPartner, trustDirection, trustType, trustAttributes, securityIdentifier
# RISK: CRITICAL
# MITRE ATT&CK: T1134.005 (Access Token Manipulation: SID-History Injection)
# ============================================================

# PowerShell Active Directory Module Implementation
# ─────────────────────────────────────────────
# DetectionConfidence : High
# DataSource          : Active Directory
# FalsePositiveRisk   : Low
# ─────────────────────────────────────────────

try {
    $searchBase = (Get-ADRootDSE).defaultNamingContext

    Import-Module ActiveDirectory -ErrorAction Stop

    # Get all forest trusts
    $forestTrusts = Get-ADTrust -Filter "TrustType -eq 'Forest'" -Properties *
    Write-Host "Found $($forestTrusts.Count) forest trusts to analyze" -ForegroundColor Cyan

    $findings = @()

    foreach ($trust in $forestTrusts) {
        $vulnerabilities = @()

        # Check if SID filtering is disabled (TREAT_AS_EXTERNAL bit NOT set)
        # Bit 0x04 (4) = TREAT_AS_EXTERNAL (quarantined = SID filter ON)
        if (($trust.TrustAttributes -band 4) -eq 0) {
            $vulnerabilities += "SID filtering disabled - ExtraSIDs attack possible"
        }

        # Check for other risky trust attributes
        if (($trust.TrustAttributes -band 8) -ne 0) {
            $vulnerabilities += "Uses RC4 encryption (bit 0x08) - downgrade risk"
        }

        if (($trust.TrustAttributes -band 32) -eq 0) {
            $vulnerabilities += "No selective authentication (bit 0x20) - broader access"
        }

        # Check trust direction for inbound component (ExtraSIDs come FROM trusted forest)
        $directionRisk = ""
        switch ($trust.Direction) {
            "Inbound" { $directionRisk = "Inbound trust - can receive ExtraSIDs from $($trust.Target)" }
            "Outbound" { $directionRisk = "Outbound trust - no direct ExtraSIDs risk" }
            "Bidirectional" { $directionRisk = "Bidirectional trust - can receive ExtraSIDs from $($trust.Target)" }
            default { $directionRisk = "Unknown direction ($($trust.Direction))" }
        }

        # Only flag trusts that can receive ExtraSIDs (inbound or bidirectional)
        if ($trust.Direction -eq "Inbound" -or $trust.Direction -eq "Bidirectional") {
            if ($vulnerabilities.Count -gt 0) {
                $severity = if (($trust.TrustAttributes -band 4) -eq 0) { "CRITICAL" } else { "HIGH" }

                $findings += [PSCustomObject]@{
                    CheckID = 'TRST-031'
                    CheckName = 'ExtraSIDs Cross Forest Attack Surface'
                    Domain = (Get-ADDomain).DNSRoot
                    ObjectDN = $trust.DistinguishedName
                    ObjectName = $trust.Target
                    FindingDetail = "Forest trust vulnerable to ExtraSIDs: $($vulnerabilities -join '; ') | $directionRisk | trustAttributes=0x$($trust.TrustAttributes.ToString('X'))"
                    Severity = $severity
                    Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
    }

    # Check for accounts with cross-forest SID History
    Write-Host "Checking for accounts with cross-forest SID History..." -ForegroundColor Cyan

    $accountsWithSidHistory = Get-ADUser -Filter "SIDHistory -like '*'" -Properties SIDHistory, SamAccountName,objectSid
    $currentDomainSid = (Get-ADDomain).DomainSID.Value

    foreach ($account in $accountsWithSidHistory) {
        foreach ($historySid in $account.SIDHistory) {
            $historySidString = $historySid.Value

            # Check if SID History belongs to a different forest (different domain SID prefix)
            if (-not $historySidString.StartsWith($currentDomainSid)) {
                $findings += [PSCustomObject]@{
                    CheckID = 'TRST-031'
                    CheckName = 'ExtraSIDs Cross Forest Attack Surface'
                    Domain = (Get-ADDomain).DNSRoot
                    ObjectDN = $account.DistinguishedName
                    ObjectName = $account.SamAccountName
                    FindingDetail = "Account has cross-forest SID History: $historySidString (potential ExtraSIDs vector)"
                    Severity = "HIGH"
                    Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
    }

    if ($findings) {
        Write-Host "Found $($findings.Count) ExtraSIDs attack surface issues" -ForegroundColor Red
        $findings | Format-Table -AutoSize
    } else {
        Write-Host 'No ExtraSIDs attack surface detected' -ForegroundColor Green
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
                adSuiteCheckId    = 'TRST-031'
                adSuiteCheckName  = 'ExtraSIDs_Cross_Forest_Attack_Surface'
                adSuiteMEDIUM   = 'MEDIUM'
                adSuiteTrust_Relationships   = 'Trust_Relationships'
                adSuiteFlag       = $true
            }
            Aces      = @()
            IsDeleted = $false
            IsACLProtected = $false
        })
    }

    $bhTs   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bhFile = Join-Path $bhDir "TRST-031_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

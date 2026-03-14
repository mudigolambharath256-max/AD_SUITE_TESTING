# =============================================================================
# COMBINED MULTI-ENGINE SCRIPT
# Check: DCs Replication Failures
# Category: Domain Controllers
# ID: DC-013
# Severity: critical
# Query: nTDSDSA objects in Configuration NC for replication metadata
# =============================================================================

$ErrorActionPreference = 'Continue'
$results = @()
$engineStatus = @{}

Write-Host "=== Multi-Engine Execution: DCs Replication Failures ===" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# ENGINE 1: PowerShell AD Module
# -----------------------------------------------------------------------------
Write-Host "ENGINE 1: PowerShell AD Module" -ForegroundColor Yellow
try {
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
    if (Get-Module ActiveDirectory) {
        $dcs = Get-ADDomainController -Filter * -ErrorAction Stop
        Write-Host "  Found $($dcs.Count) Domain Controllers" -ForegroundColor Green

        foreach ($dc in $dcs) {
            try {
                $replMetadata = Get-ADReplicationPartnerMetadata -Target $dc.HostName -ErrorAction SilentlyContinue

                if (-not $replMetadata) {
                    $results += [PSCustomObject]@{
                        Engine = 'PowerShell'
                        Name = $dc.Name
                        DNSHostName = $dc.HostName
                        Site = $dc.Site
                        IssueType = 'Metadata Unavailable'
                        Details = 'Unable to retrieve replication metadata'
                    }
                    continue
                }

                foreach ($partner in $replMetadata) {
                    if ($partner.ConsecutiveReplicationFailures -gt 0) {
                        $results += [PSCustomObject]@{
                            Engine = 'PowerShell'
                            Name = $dc.Name
                            DNSHostName = $dc.HostName
                            Site = $dc.Site
                            Partner = $partner.Partner
                            Partition = $partner.Partition
                            IssueType = 'Consecutive Failures'
                            Details = "Failures: $($partner.ConsecutiveReplicationFailures)"
                            LastSuccess = $partner.LastReplicationSuccess
                        }
                    }

                    if ($partner.LastReplicationSuccess) {
                        $hoursSinceSuccess = ((Get-Date) - $partner.LastReplicationSuccess).TotalHours
                        if ($hoursSinceSuccess -gt 4) {
                            $results += [PSCustomObject]@{
                                Engine = 'PowerShell'
                                Name = $dc.Name
                                DNSHostName = $dc.HostName
                                Site = $dc.Site
                                Partner = $partner.Partner
                                Partition = $partner.Partition
                                IssueType = 'Stale Replication'
                                Details = "Last success: $([math]::Round($hoursSinceSuccess, 2)) hours ago"
                                LastSuccess = $partner.LastReplicationSuccess
                            }
                        }
                    }
                }
            } catch {
                $results += [PSCustomObject]@{
                    Engine = 'PowerShell'
                    Name = $dc.Name
                    DNSHostName = $dc.HostName
                    IssueType = 'Query Error'
                    Details = $_.Exception.Message
                }
            }
        }
        $engineStatus['PowerShell'] = 'Success'
        Write-Host "  PowerShell AD Module: SUCCESS" -ForegroundColor Green
    } else {
        $engineStatus['PowerShell'] = 'Module not available'
        Write-Host "  PowerShell AD Module: NOT AVAILABLE" -ForegroundColor Red
    }
} catch {
    $engineStatus['PowerShell'] = "Error: $($_.Exception.Message)"
    Write-Host "  PowerShell
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
                adSuiteCheckId    = 'DC-013'
                adSuiteCheckName  = 'DCs_Replication_Failures'
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
    $bhFile = Join-Path $bhDir "DC-013_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

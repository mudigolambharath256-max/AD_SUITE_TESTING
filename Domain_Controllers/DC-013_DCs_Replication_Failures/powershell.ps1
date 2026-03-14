# Check: DCs Replication Failures
# Category: Domain Controllers
# Severity: critical
# ID: DC-013
# Requirements: ActiveDirectory module (RSAT)
# ============================================
# Query: nTDSDSA objects in Configuration NC for replication metadata

# LDAP search (PowerShell AD module)
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

try {
    # Get all Domain Controllers
    $dcs = Get-ADDomainController -Filter * -ErrorAction Stop
    Write-Host "Found $($dcs.Count) Domain Controllers" -ForegroundColor Cyan

    $output = @()

    foreach ($dc in $dcs) {
        try {
            # Get replication metadata for this DC
            $replMetadata = Get-ADReplicationPartnerMetadata -Target $dc.HostName -ErrorAction SilentlyContinue

            if (-not $replMetadata) {
                $output += [PSCustomObject]@{
                    Label                   = 'DC Replication Failure'
                    Name                    = $dc.Name
                    DistinguishedName       = $dc.ComputerObjectDN
                    DNSHostName             = $dc.HostName
                    Site                    = $dc.Site
                    IssueReason             = 'Unable to retrieve replication metadata'
                    LastReplicationAttempt  = 'N/A'
                    LastReplicationSuccess  = 'N/A'
                    ConsecutiveFailures     = 'N/A'
                }
                continue
            }

            foreach ($partner in $replMetadata) {
                $hasFailure = $false
                $issueReason = @()

                # Check for consecutive failures
                if ($partner.ConsecutiveReplicationFailures -gt 0) {
                    $hasFailure = $true
                    $issueReason += "Consecutive failures: $($partner.ConsecutiveReplicationFailures)"
                }

                # Check last successful replication time
                if ($partner.LastReplicationSuccess) {
                    $hoursSinceSuccess = ((Get-Date) - $partner.LastReplicationSuccess).TotalHours
                    if ($hoursSinceSuccess -gt 4) {
                        $hasFailure = $true
                        $issueReason += "Last success > 4 hours ago ($([math]::Round($hoursSinceSuccess, 2)) hours)"
                    }
                }

                if ($hasFailure) {
                    $output += [PSCustomObject]@{
                        Label                   = 'DC Replication Failure'
                        Name                    = $dc.Name
                        DistinguishedName       = $dc.ComputerObjectDN
                        DNSHostName             = $dc.HostName
                        Site                    = $dc.Site
                        Partner                 = $partner.Partner
                        Partition               = $partner.Partition
                        IssueReason             = ($issueReason -join '; ')
                        LastReplicationAttempt  = $partner.LastReplicationAttempt
                        LastReplicationSuccess  = $partner.LastReplicationSuccess
                        ConsecutiveFailures     = $partner.ConsecutiveReplicationFailures
                    }
                }
            }
        } catch {
            $output += [PSCustomObject]@{
                Label                   = 'DC Replication Failure'
                Name                    = $dc.Name
                DistinguishedName       = $dc.ComputerObjectDN
                DNSHostName             = $dc.HostName
                Site                    = $dc.Site
                IssueReason             = "Query failed: $($_.Exception.Message)"
                LastReplicationAttempt  = 'N/A'
                LastReplicationSuccess  = 'N/A'
                ConsecutiveFailures     = 'N/A'
            }
        }
    }

    if ($output) {
        Write-Host "Found $($output.Count) replication issues" -ForegroundColor Yellow
        $output | Sort-Object Name | Format-Table -AutoSize
    } else {
        Write-Host 'No replication failures detected' -ForegroundColor Green
    }
} catch {
    Write-Error "PowerShell AD module query failed: $_"
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

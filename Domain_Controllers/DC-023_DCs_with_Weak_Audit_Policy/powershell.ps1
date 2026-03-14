# DC-047: DCs with Weak Audit Policy
# Identifies Domain Controllers with insufficient audit policy configuration

Import-Module ActiveDirectory -ErrorAction Stop

$results = @()

# Define critical audit categories that should be enabled
$criticalAuditCategories = @{
    "Account Logon" = @("Credential Validation")
    "Account Management" = @("User Account Management", "Security Group Management")
    "Logon/Logoff" = @("Logon", "Logoff", "Account Lockout")
    "Object Access" = @("File System", "Registry")
    "Policy Change" = @("Audit Policy Change", "Authentication Policy Change")
    "Privilege Use" = @("Sensitive Privilege Use")
    "System" = @("Security State Change", "Security System Extension")
}

try {
    # Get all Domain Controllers
    $dcs = Get-ADDomainController -Filter * | Select-Object Name, HostName

    foreach ($dc in $dcs) {
        $hostname = $dc.HostName

        Write-Host "Checking $hostname..." -ForegroundColor Cyan

        # Test connectivity
        if (-not (Test-Connection -ComputerName $hostname -Count 1 -Quiet)) {
            Write-Verbose "$hostname is unreachable"
            continue
        }

        try {
            # Get audit policy via auditpol
            $auditOutput = Invoke-Command -ComputerName $hostname -ScriptBlock {
                auditpol /get /category:* 2>&1 | Out-String
            } -ErrorAction Stop

            $weakCategories = @()

            # Check for "No Auditing" in critical categories
            foreach ($category in $criticalAuditCategories.Keys) {
                if ($auditOutput -match "$category.*No Auditing") {
                    $weakCategories += $category
                }
            }

            if ($weakCategories.Count -gt 0) {
                $results += [PSCustomObject]@{
                    Name = $dc.Name
                    HostName = $hostname
                    WeakCategories = ($weakCategories -join '; ')
                    Status = "Weak audit policy detected"
                    Risk = "HIGH - Insufficient logging for forensics"
                    Recommendation = "Enable auditing for critical categories"
                    Label = 'DC-047'
                    Check = 'DCs with Weak Audit Policy'
                }
            }

        } catch {
            Write-Verbose "Error checking $hostname : $_"
        }
    }

    # Display results
    if ($results.Count -gt 0) {
        Write-Host "`nDomain Controllers with Weak Audit Policy:" -ForegroundColor Red
        $results | Format-Table -AutoSize

    } else {
        Write-Host "`nNo Domain Controllers with weak audit policy found." -ForegroundColor Green
    }

} catch {
    Write-Error "Error executing check: $_"
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
                adSuiteCheckId    = 'DC-023'
                adSuiteCheckName  = 'DCs_with_Weak_Audit_Policy'
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
    $bhFile = Join-Path $bhDir "DC-023_$bhTs.json"
    @{
        data = $bhNodes.ToArray()
        meta = @{ type = 'domains'; count = $bhNodes.Count; version = 5; methods = 0 }
    } | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $bhFile -Encoding UTF8 -Force
} catch { }
# ── End BloodHound Export ─────────────────────────────────────────────────────

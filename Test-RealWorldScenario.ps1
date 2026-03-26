#requires -Version 5.1
<#
.SYNOPSIS
    Real-world scenario test: Execute 10 randomly selected AD security checks

.DESCRIPTION
    Simulates a security audit workflow with detailed logging and data flow tracing.
    Tests the complete execution pipeline from parameter validation to result output.

.PARAMETER ServerName
    Domain Controller hostname (default: auto-detect from environment)

.PARAMETER OutputDir
    Directory for test results (default: .\TestResults)

.PARAMETER Verbose
    Enable detailed data flow tracing

.EXAMPLE
    .\Test-RealWorldScenario.ps1 -ServerName kingslanding.sevenkingdoms.local -Verbose
#>
[CmdletBinding()]
param(
    [string]$ServerName,
    [string]$OutputDir = ".\TestResults",
    [switch]$DetailedTrace
)

$ErrorActionPreference = 'Continue'

# Create output directory
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Test configuration
$testChecks = @(
    @{Id='KRB-002'; Name='AS-REP Roastable Accounts'; Expected='FAIL'; Priority='HIGH'},
    @{Id='DC-036'; Name='DCs with Expiring Certificates'; Expected='VARIABLE'; Priority='MEDIUM'},
    @{Id='DC-050'; Name='DCs with Disabled Windows Firewall'; Expected='FAIL'; Priority='HIGH'},
    @{Id='PKI-003'; Name='Certificate Template Permissions'; Expected='FAIL'; Priority='HIGH'},
    @{Id='TRST-014'; Name='Trusts Created Recently 30 Days'; Expected='VARIABLE'; Priority='MEDIUM'},
    @{Id='AAD-025'; Name='Accounts with Azure AD Device Registration'; Expected='PASS'; Priority='LOW'},
    @{Id='INFRA-014'; Name='DNS Scavenging Settings'; Expected='VARIABLE'; Priority='LOW'},
    @{Id='NET-006'; Name='DNS Scavenging Configuration'; Expected='VARIABLE'; Priority='LOW'},
    @{Id='SECACCT-027'; Name='Resource Properties'; Expected='PASS'; Priority='LOW'},
    @{Id='SMB-008'; Name='SMB Shares with Weak Permissions'; Expected='FAIL'; Priority='HIGH'}
)

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  AD SUITE - REAL WORLD SCENARIO TEST                          ║" -ForegroundColor Cyan
Write-Host "║  Testing 10 Security Checks with Data Flow Tracing            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Test 1: Verify environment
Write-Host "[Phase 1] Environment Verification" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray

$envChecks = @{
    'adsi.ps1' = Test-Path '.\adsi.ps1'
    'checks.json' = Test-Path '.\checks.json'
    'checks.generated.json' = Test-Path '.\checks.generated.json'
    'Module' = Test-Path '.\Modules\ADSuite.Adsi.psm1'
}

foreach ($check in $envChecks.GetEnumerator()) {
    $status = if ($check.Value) { "[✓]" } else { "[✗]" }
    $color = if ($check.Value) { "Green" } else { "Red" }
    Write-Host "  $status $($check.Key)" -ForegroundColor $color
}

if ($envChecks.Values -contains $false) {
    Write-Host "`n[ERROR] Environment check failed. Ensure all files are present." -ForegroundColor Red
    exit 1
}

Write-Host "  [✓] All files present" -ForegroundColor Green
Write-Host ""

# Test 2: Load and validate checks
Write-Host "[Phase 2] Configuration Loading" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray

try {
    $config = Get-Content '.\checks.generated.json' -Raw | ConvertFrom-Json
    Write-Host "  [✓] Loaded checks.generated.json" -ForegroundColor Green
    Write-Host "  [i] Total checks available: $($config.checks.Count)" -ForegroundColor Cyan
    
    # Verify test checks exist
    $missingChecks = @()
    foreach ($testCheck in $testChecks) {
        $found = $config.checks | Where-Object { $_.id -eq $testCheck.Id }
        if (-not $found) {
            $missingChecks += $testCheck.Id
        }
    }
    
    if ($missingChecks.Count -gt 0) {
        Write-Host "  [✗] Missing checks: $($missingChecks -join ', ')" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  [✓] All test checks found in configuration" -ForegroundColor Green
} catch {
    Write-Host "  [✗] Failed to load configuration: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 3: Module import
Write-Host "[Phase 3] Module Import" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray

try {
    Import-Module '.\Modules\ADSuite.Adsi.psm1' -Force -ErrorAction Stop
    Write-Host "  [✓] Module imported successfully" -ForegroundColor Green
    
    $exportedFunctions = @(
        'Get-ADSuiteRootDse',
        'Resolve-ADSuiteSearchRoot',
        'Invoke-ADSuiteLdapQuery',
        'Get-AdsProperty',
        'Test-UserAccountControlMask',
        'ConvertTo-ADSuiteFindingRow'
    )
    
    foreach ($func in $exportedFunctions) {
        if (Get-Command $func -ErrorAction SilentlyContinue) {
            Write-Host "    [✓] $func" -ForegroundColor Green
        } else {
            Write-Host "    [✗] $func not found" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "  [✗] Module import failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 4: LDAP connectivity (if ServerName provided)
if ($ServerName) {
    Write-Host "[Phase 4] LDAP Connectivity Test" -ForegroundColor Yellow
    Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  [i] Target: $ServerName" -ForegroundColor Cyan
    
    try {
        $rootDse = Get-ADSuiteRootDse -ServerName $ServerName
        Write-Host "  [✓] Connected to RootDSE" -ForegroundColor Green
        Write-Host "    Domain: $($rootDse.DefaultNamingContext)" -ForegroundColor Gray
        Write-Host "    Config: $($rootDse.ConfigurationNamingContext)" -ForegroundColor Gray
        Write-Host "    Schema: $($rootDse.SchemaNamingContext)" -ForegroundColor Gray
        Write-Host "    DNS: $($rootDse.DnsHostName)" -ForegroundColor Gray
    } catch {
        Write-Host "  [✗] LDAP connection failed: $_" -ForegroundColor Red
        Write-Host "  [i] Continuing with local domain..." -ForegroundColor Yellow
        $ServerName = $null
    }
    Write-Host ""
}

# Test 5: Execute checks
Write-Host "[Phase 5] Check Execution" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray

$testResults = @()
$executionLog = @()

foreach ($testCheck in $testChecks) {
    $checkId = $testCheck.Id
    $checkName = $testCheck.Name
    $priority = $testCheck.Priority
    
    Write-Host "`n  ┌─ Check: $checkId" -ForegroundColor Cyan
    Write-Host "  │  Name: $checkName" -ForegroundColor Gray
    Write-Host "  │  Priority: $priority" -ForegroundColor Gray
    Write-Host "  │  Expected: $($testCheck.Expected)" -ForegroundColor Gray
    
    $startTime = Get-Date
    
    try {
        # Build command
        $cmd = ".\adsi.ps1 -CheckId $checkId -PassThru"
        if ($ServerName) {
            $cmd += " -ServerName $ServerName"
        }
        
        if ($DetailedTrace) {
            Write-Host "  │  Command: $cmd" -ForegroundColor DarkGray
        }
        
        # Execute check
        $output = Invoke-Expression $cmd 2>&1
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        # Analyze results
        if ($output -is [array] -and $output.Count -gt 0) {
            $findingCount = $output[0].FindingCount
            $result = $output[0].Result
        } elseif ($output) {
            $findingCount = $output.FindingCount
            $result = $output.Result
        } else {
            $findingCount = 0
            $result = "Pass"
        }
        
        # Determine status
        $status = if ($result -eq "Pass") { "✓" } else { "⚠" }
        $statusColor = if ($result -eq "Pass") { "Green" } else { "Yellow" }
        
        Write-Host "  │  [$status] Result: $result" -ForegroundColor $statusColor
        Write-Host "  │  Findings: $findingCount" -ForegroundColor $statusColor
        Write-Host "  │  Duration: $([math]::Round($duration, 2))ms" -ForegroundColor Gray
        
        # Log execution details
        $executionLog += [PSCustomObject]@{
            Timestamp = $startTime
            CheckId = $checkId
            CheckName = $checkName
            Priority = $priority
            Expected = $testCheck.Expected
            ActualResult = $result
            FindingCount = $findingCount
            DurationMs = [math]::Round($duration, 2)
            Status = 'Success'
            ErrorMessage = $null
        }
        
        # Store results
        if ($output) {
            $testResults += $output
        }
        
        Write-Host "  └─ Status: SUCCESS" -ForegroundColor Green
        
    } catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        Write-Host "  │  [✗] Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  └─ Status: FAILED" -ForegroundColor Red
        
        $executionLog += [PSCustomObject]@{
            Timestamp = $startTime
            CheckId = $checkId
            CheckName = $checkName
            Priority = $priority
            Expected = $testCheck.Expected
            ActualResult = 'ERROR'
            FindingCount = 0
            DurationMs = [math]::Round($duration, 2)
            Status = 'Failed'
            ErrorMessage = $_.Exception.Message
        }
    }
}

Write-Host ""

# Test 6: Results analysis
Write-Host "[Phase 6] Results Analysis" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray

$successCount = ($executionLog | Where-Object { $_.Status -eq 'Success' }).Count
$failedCount = ($executionLog | Where-Object { $_.Status -eq 'Failed' }).Count
$totalFindings = ($executionLog | Measure-Object -Property FindingCount -Sum).Sum
$avgDuration = ($executionLog | Measure-Object -Property DurationMs -Average).Average

Write-Host "  Execution Summary:" -ForegroundColor Cyan
Write-Host "    Total Checks: $($testChecks.Count)" -ForegroundColor Gray
Write-Host "    Successful: $successCount" -ForegroundColor Green
Write-Host "    Failed: $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { 'Red' } else { 'Gray' })
Write-Host "    Total Findings: $totalFindings" -ForegroundColor Yellow
Write-Host "    Avg Duration: $([math]::Round($avgDuration, 2))ms" -ForegroundColor Gray

Write-Host ""

# Priority breakdown
$highPriority = $executionLog | Where-Object { $_.Priority -eq 'HIGH' }
$highFindings = ($highPriority | Measure-Object -Property FindingCount -Sum).Sum

Write-Host "  Priority Breakdown:" -ForegroundColor Cyan
Write-Host "    HIGH Priority Checks: $($highPriority.Count)" -ForegroundColor Red
Write-Host "    HIGH Priority Findings: $highFindings" -ForegroundColor Red

Write-Host ""

# Test 7: Export results
Write-Host "[Phase 7] Export Results" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

# Export execution log
$logPath = Join-Path $OutputDir "ExecutionLog_$timestamp.csv"
$executionLog | Export-Csv -Path $logPath -NoTypeInformation
Write-Host "  [✓] Execution log: $logPath" -ForegroundColor Green

# Export findings
if ($testResults.Count -gt 0) {
    $resultsPath = Join-Path $OutputDir "Findings_$timestamp.csv"
    $testResults | Export-Csv -Path $resultsPath -NoTypeInformation
    Write-Host "  [✓] Findings: $resultsPath" -ForegroundColor Green
} else {
    Write-Host "  [i] No findings to export" -ForegroundColor Gray
}

# Export summary report
$summaryPath = Join-Path $OutputDir "Summary_$timestamp.txt"
$summary = @"
═══════════════════════════════════════════════════════════════
  AD SUITE - REAL WORLD SCENARIO TEST SUMMARY
═══════════════════════════════════════════════════════════════

Test Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Target DC: $(if ($ServerName) { $ServerName } else { 'Local Domain' })

EXECUTION STATISTICS
────────────────────────────────────────────────────────────────
Total Checks Executed:     $($testChecks.Count)
Successful Executions:     $successCount
Failed Executions:         $failedCount
Total Findings Detected:   $totalFindings
Average Execution Time:    $([math]::Round($avgDuration, 2))ms

PRIORITY ANALYSIS
────────────────────────────────────────────────────────────────
HIGH Priority Checks:      $($highPriority.Count)
HIGH Priority Findings:    $highFindings

DETAILED RESULTS
────────────────────────────────────────────────────────────────
$($executionLog | Format-Table -AutoSize | Out-String)

FINDINGS BREAKDOWN
────────────────────────────────────────────────────────────────
$(if ($testResults.Count -gt 0) {
    $testResults | Group-Object CheckId | ForEach-Object {
        "  $($_.Name): $($_.Count) finding(s)"
    } | Out-String
} else {
    "  No findings detected (all checks passed)"
})

═══════════════════════════════════════════════════════════════
"@

$summary | Out-File -FilePath $summaryPath -Encoding UTF8
Write-Host "  [✓] Summary report: $summaryPath" -ForegroundColor Green

Write-Host ""

# Final status
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  TEST COMPLETED                                                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

if ($failedCount -eq 0) {
    Write-Host "`n[✓] All checks executed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n[⚠] $failedCount check(s) failed to execute. Review logs for details." -ForegroundColor Yellow
    exit 1
}

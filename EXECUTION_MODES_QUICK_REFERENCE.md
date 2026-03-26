# AD Suite - Execution Modes Quick Reference

## 🎯 Three Execution Modes at a Glance

| Feature | Single Check Runner | Batch Scanner | UI Dashboard |
|---------|-------------------|---------------|--------------|
| **Script** | `adsi.ps1` | `Invoke-ADSuiteScan.ps1` | `ui/dashboard.html` |
| **Purpose** | Targeted checks | Full risk assessments | Visual analysis |
| **Speed** | 200-700ms per check | 5-15 min for 756 checks | Instant (loads JSON) |
| **Output** | Console/Pipeline | JSON/CSV/HTML | Interactive browser |
| **Risk Scoring** | ❌ No | ✅ Yes (0-100) | ✅ Yes (visualized) |
| **Best For** | Pentesting, CI/CD | Audits, compliance | Reporting, planning |

---

## 🚀 Mode 1: Single Check Runner (`adsi.ps1`)

### When to Use
- Quick security checks during penetration testing
- Targeted investigation of specific vulnerabilities
- CI/CD security gates
- Learning and exploration
- Debugging check definitions

### Quick Commands

```powershell
# Basic usage (clean output)
.\adsi.ps1 -CheckId KRB-002 -CompactOutput

# Against specific DC
.\adsi.ps1 -CheckId ACC-001 -ServerName dc01.domain.local -CompactOutput

# CI/CD security gate
.\adsi.ps1 -CheckId ACC-034 -Quiet -FailOnFindings
if ($LASTEXITCODE -eq 3) { exit 1 }

# Pipeline processing
.\adsi.ps1 -CheckId ACC-001 -PassThru | Export-Csv results.csv -NoTypeInformation

# View in grid
.\adsi.ps1 -CheckId ACC-001 -PassThru | Out-GridView
```

### Key Parameters
- `-CheckId` - Check identifier (required)
- `-CompactOutput` - Show only AD properties (recommended)
- `-PassThru` - Output objects to pipeline
- `-Quiet` - Suppress host output
- `-FailOnFindings` - Exit code 3 if findings detected

### Exit Codes
- `0` = Success (no findings or not using -FailOnFindings)
- `1` = Configuration error
- `2` = Wrong engine
- `3` = Findings detected (with -FailOnFindings)

---

## 🔍 Mode 2: Batch Scanner (`Invoke-ADSuiteScan.ps1`)

### When to Use
- Purple Knight / Ping Castle-style full AD assessments
- Scheduled security audits
- Compliance reporting
- Risk scoring and trending
- Category-scoped assessments

### Quick Commands

```powershell
# Full risk assessment
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\latest

# Category-scoped scan
.\Invoke-ADSuiteScan.ps1 `
    -ChecksJsonPath .\checks.json `
    -Category Kerberos_Security,Certificate_Services `
    -OutputDirectory .\out\kerberos-adcs

# Specific checks only
.\Invoke-ADSuiteScan.ps1 `
    -ChecksJsonPath .\checks.json `
    -IncludeCheckId KRB-002,ACC-034,CERT-002 `
    -OutputDirectory .\out\critical

# Against specific DC
.\Invoke-ADSuiteScan.ps1 `
    -ChecksJsonPath .\checks.json `
    -ServerName dc01.domain.local `
    -OutputDirectory .\out\dc01
```

### Key Parameters
- `-ChecksJsonPath` - Path to catalog (use `.\checks.json` for production)
- `-OutputDirectory` - Output folder (default: `.\out\scan-<timestamp>`)
- `-Category` - Filter by category names
- `-IncludeCheckId` - Only run these check IDs
- `-ExcludeCheckId` - Skip these check IDs
- `-ServerName` - Target DC
- `-FindingCapPerCheck` - Max findings per check for scoring (default: 10)
- `-ScoringNormalizer` - Score normalization divisor (default: 5)

### Output Files
- `scan-results.json` - Complete scan data with metadata, scores, findings
- `findings.csv` - Flattened CSV for spreadsheet analysis
- `report.html` - HTML summary with dashboard link

### Risk Scoring
```
Per-Check Score:
  weight = severity weight (info=1, low=2, medium=3, high=4, critical=5)
  capped = min(FindingCount, FindingCapPerCheck)
  CheckScore = weight × capped × scoreWeight

Global Score (0-100):
  globalRaw = sum(CheckScore)
  globalScore = min(100, ceil(globalRaw / ScoringNormalizer))
  
Risk Bands:
  0-25   = Low
  26-50  = Moderate
  51-75  = High
  76-100 = Critical
```

---

## 📊 Mode 3: UI Dashboard (`ui/dashboard.html`)

### When to Use
- Executive reporting and visualization
- Interactive finding exploration
- Category-based filtering
- Scan planning and command generation
- Offline analysis (no data leaves browser)

### Quick Commands

```powershell
# 1. Run a scan
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\latest

# 2. Generate catalog summary (optional, for scan planner)
.\tools\Export-ADSuiteCatalogSummary.ps1

# 3. Open dashboard
start .\ui\dashboard.html

# 4. In browser:
#    - Click "Load scan results" and select .\out\latest\scan-results.json
#    - Click "Load catalog summary" and select .\ui\catalog-summary.json (optional)
```

### Features
- **Global Risk Score** - Visual card showing 0-100 score with risk band
- **Summary Cards** - Checks run, with findings, errors, total findings
- **Category Breakdown** - Table showing checks, findings, errors per category
- **Top 10 Risks** - Highest scoring checks by severity × findings
- **Category Filters** - Click chips to filter checks table
- **Sortable Columns** - Click headers to sort
- **Expandable Details** - Click "Details" to see description, remediation, references, findings
- **Scan Planner** - Generate commands for category-scoped scans
- **Export** - Download filtered results as JSON
- **Print** - Print-friendly layout

### Scan Planner
1. Load `catalog-summary.json` in dashboard
2. Check "Full catalog scan" for complete assessment, OR
3. Select specific categories for scoped scan
4. Optionally add specific check IDs to include
5. Copy generated command and run in PowerShell

---

## 🗂️ Catalog Files

### checks.json (Production Risk Pack)
**Use for:** Production risk scans, audits, compliance

**Characteristics:**
- Curated, reviewed checks
- Complete metadata (description, remediation, references)
- `engine: ldap` or `engine: filesystem`
- Ready for risk scoring

**Command:**
```powershell
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json
```

### checks.overrides.json (Patches)
**Use for:** Override specific fields without duplicating definitions

**Characteristics:**
- Partial check objects keyed by `id`
- Non-null fields override base catalog
- Promote checks from inventory to production
- Adjust severity, fix filters, add metadata

**Auto-loaded** if exists next to `Invoke-ADSuiteScan.ps1`

### checks.generated.json (Full Inventory)
**Use for:** Reference, exploration, debugging

**Characteristics:**
- 756 checks from legacy scripts
- All checks default to `engine: inventory`
- NOT for production risk scans (all checks skipped)
- Individual checks promoted via overrides

**Command (for exploration only):**
```powershell
.\adsi.ps1 -CheckId SOME-ID -ChecksJsonPath .\checks.generated.json
```

---

## 🎯 Common Workflows

### Workflow 1: Quick Pentest Check
```powershell
# Check for AS-REP roastable accounts
.\adsi.ps1 -CheckId KRB-002 -ServerName target-dc.domain.local -CompactOutput
```

### Workflow 2: Full Security Audit
```powershell
# Run comprehensive scan
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\audit-2024

# Open dashboard for analysis
start .\ui\dashboard.html
# Load .\out\audit-2024\scan-results.json
```

### Workflow 3: Category-Focused Assessment
```powershell
# Focus on Kerberos and ADCS
.\Invoke-ADSuiteScan.ps1 `
    -ChecksJsonPath .\checks.json `
    -Category Kerberos_Security,Certificate_Services `
    -OutputDirectory .\out\kerberos-adcs

# View results
start .\ui\dashboard.html
```

### Workflow 4: CI/CD Security Gate
```powershell
# Check critical vulnerabilities
$checks = @('KRB-002', 'ACC-034', 'ACC-037', 'CERT-002')
foreach ($check in $checks) {
    .\adsi.ps1 -CheckId $check -Quiet -FailOnFindings
    if ($LASTEXITCODE -eq 3) {
        Write-Error "Critical issue: $check"
        exit 1
    }
}
```

### Workflow 5: Scheduled Weekly Audit
```powershell
# Schedule this script
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputPath = "\\share\audits\$timestamp"

.\Invoke-ADSuiteScan.ps1 `
    -ChecksJsonPath .\checks.json `
    -OutputDirectory $outputPath

# Email report
Send-MailMessage `
    -To "security@company.com" `
    -Subject "Weekly AD Audit - $timestamp" `
    -Attachments "$outputPath\report.html"
```

### Workflow 6: Incident Response Triage
```powershell
# Quick triage of critical checks
$critical = @('ACC-033', 'ACC-037', 'KRB-002', 'ACC-027')
foreach ($c in $critical) {
    Write-Host "`n=== $c ===" -ForegroundColor Cyan
    .\adsi.ps1 -CheckId $c -CompactOutput | Tee-Object -FilePath "triage-$c.txt"
}
```

---

## 📈 Performance Guide

| Operation | Time | Notes |
|-----------|------|-------|
| Single check | 200-700ms | Depends on result count |
| 10 checks (single runner) | 2-7 seconds | Sequential execution |
| 50 checks (batch scanner) | 10-35 seconds | Full category scan |
| 756 checks (batch scanner) | 5-15 minutes | Complete inventory |
| Dashboard load | Instant | Client-side JSON parsing |

---

## 🔐 Security Considerations

### Single Check Runner
- Uses current user's credentials
- LDAP traffic unencrypted by default
- Queries logged in AD event logs
- Some checks require elevated privileges

### Batch Scanner
- Same as single check runner
- Generates files with sensitive AD data
- Secure output directory appropriately
- Consider LDAPS for sensitive environments

### UI Dashboard
- 100% client-side (no uploads)
- scan-results.json contains sensitive data
- Treat exports like security assessment output
- Restrict sharing and storage

---

## 🛠️ Troubleshooting

### Issue: Output shows metadata instead of AD properties
**Solution:** Use `-CompactOutput` parameter
```powershell
.\adsi.ps1 -CheckId ACC-001 -CompactOutput
```

### Issue: LDAP connection failed
**Solution:** Specify ServerName explicitly
```powershell
.\adsi.ps1 -CheckId ACC-001 -ServerName dc01.domain.local
```

### Issue: Execution policy error
**Solution:** Set execution policy
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

### Issue: Batch scanner skips all checks
**Solution:** Use `checks.json` (not `checks.generated.json`)
```powershell
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json
```

### Issue: Dashboard shows no data
**Solution:** Load `scan-results.json` from batch scanner output
```powershell
# First run scan
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\latest

# Then open dashboard and load .\out\latest\scan-results.json
start .\ui\dashboard.html
```

---

## 📚 Additional Resources

- **[COMPLETE_ARCHITECTURE.md](COMPLETE_ARCHITECTURE.md)** - Detailed architecture documentation
- **[README.md](README.md)** - Main project documentation
- **[QUICK_START_GUIDE.md](QUICK_START_GUIDE.md)** - Complete command reference
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Comprehensive troubleshooting guide
- **[docs/RISK_PACK.md](docs/RISK_PACK.md)** - Risk pack contract and engine types
- **[ui/README.md](ui/README.md)** - UI dashboard documentation

---

## 🎉 Quick Decision Tree

```
Need quick answer about specific vulnerability?
  → Use Single Check Runner (adsi.ps1)

Need comprehensive risk assessment?
  → Use Batch Scanner (Invoke-ADSuiteScan.ps1)

Need visual analysis or executive report?
  → Use UI Dashboard (ui/dashboard.html)

Need to plan next scan?
  → Use UI Dashboard scan planner

Need CI/CD integration?
  → Use Single Check Runner with -FailOnFindings

Need scheduled audits?
  → Use Batch Scanner in scheduled task

Need to explore catalog?
  → Use UI Dashboard with catalog-summary.json
```

---

**Made with ❤️ for the AD security community**

**Repository:** https://github.com/mudigolambharath256-max/AD_SUITE_TESTING  
**Branch:** mod

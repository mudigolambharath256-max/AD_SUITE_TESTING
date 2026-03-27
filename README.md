# AD Suite - Active Directory Security Auditing Framework

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows-lightgrey.svg)](https://www.microsoft.com/windows)

**AD Suite** is a Windows PowerShell AD assessment toolkit. It reads check definitions from JSON catalogs, runs LDAP (and filesystem) checks using ADSI/DirectorySearcher—**no ActiveDirectory module required**. Results can be JSON, CSV, HTML, and optionally viewed in a static browser UI.

## 🎯 Features

- ✅ **756 Security Checks** across 26 categories
- ✅ **Pure ADSI Implementation** - No AD module dependency
- ✅ **Three Execution Modes** - Single check, batch scanner, UI dashboard
- ✅ **Purple Knight-Style Dashboard** - Interactive visual analysis
- ✅ **Risk Scoring System** - Global 0-100 score with severity weighting
- ✅ **GOAD Lab Compatible** - Perfect for penetration testing practice
- ✅ **JSON-Based Configuration** - Easy to extend and customize
- ✅ **Comprehensive Coverage** - Kerberos, ADCS, Delegation, Trusts, and more

## 📊 Check Categories

| Category | Checks | Focus Area |
|----------|--------|------------|
| Certificate Services | 53 | ADCS, PKI, ESC1-8 vulnerabilities |
| Group Policy | 50 | GPO security and configuration |
| Kerberos Security | 45 | Kerberoasting, delegation, encryption |
| Azure AD Integration | 42 | Hybrid identity security |
| Domain Controllers | 38 | DC inventory and hardening |
| Computer Management | 37 | Computer account security |
| Users & Accounts | 35 | User account vulnerabilities |
| And 19 more... | 456 | Complete AD security coverage |

## 🚀 Quick Start

### Prerequisites
- Windows with PowerShell 5.1+
- LDAP access to Active Directory (typically domain-joined machine)
- No additional modules required

### Installation

```powershell
# Clone the repository
git clone -b mod https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
cd AD_SUITE_TESTING

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

### Basic Usage

```powershell
# Single check (curated catalog)
.\adsi.ps1 -CheckId ACC-001
.\adsi.ps1 -CheckId ACC-001 -ServerName dc01.contoso.local -CompactOutput

# Full risk scan (curated checks.json)
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\latest

# Full scan using generated catalog + Phase B overrides (hundreds of checks)
.\Invoke-ADSuiteScan.ps1 `
    -ChecksJsonPath .\checks.generated.json `
    -ChecksOverridesPath .\checks.overrides.phaseB-complete.json `
    -OutputDirectory .\out\latest

# Validate catalog
.\Test-ADSuiteCatalog.ps1 -CatalogPath .\checks.json
```

## 🔥 Popular Security Checks

### Kerberos Attacks
```powershell
# AS-REP Roastable Accounts
.\adsi.ps1 -CheckId KRB-002 -CompactOutput

# Kerberoastable Accounts
.\adsi.ps1 -CheckId ACC-034 -CompactOutput

# Unconstrained Delegation
.\adsi.ps1 -CheckId ACC-027 -CompactOutput

# Resource-Based Constrained Delegation (RBCD)
.\adsi.ps1 -CheckId ACC-039 -CompactOutput
```

### Privileged Access
```powershell
# Privileged Users (adminCount=1)
.\adsi.ps1 -CheckId ACC-001 -CompactOutput

# Domain Admins
.\adsi.ps1 -CheckId ACC-014 -CompactOutput

# Enterprise Admins
.\adsi.ps1 -CheckId ACC-015 -CompactOutput
```

### Certificate Services (ADCS)
```powershell
# ESC1 - Templates Allowing SAN
.\adsi.ps1 -CheckId CERT-002 -CompactOutput

# ESC4 - Weak Access Control
.\adsi.ps1 -CheckId CERT-005 -CompactOutput
```

### Advanced Attacks
```powershell
# Shadow Credentials
.\adsi.ps1 -CheckId ACC-037 -CompactOutput

# DCSync Rights
.\adsi.ps1 -CheckId ACC-033 -CompactOutput
```

## 📋 Execution Modes

### Mode 1: Single Check Runner (`adsi.ps1`)
Execute individual security checks interactively or in automation.

```powershell
# Basic usage
.\adsi.ps1 -CheckId ACC-001
.\adsi.ps1 -CheckId ACC-001 -ServerName dc01.contoso.local -CompactOutput

# CI/CD security gate
.\adsi.ps1 -CheckId ACC-001 -Quiet -FailOnFindings
# Exit code 0 = Pass, 3 = Findings detected

# Pipeline processing
.\adsi.ps1 -CheckId ACC-001 -PassThru | Export-Csv results.csv
```

**Use Cases:** Pentesting, targeted checks, CI/CD gates, debugging

### Mode 2: Batch Scanner (`Invoke-ADSuiteScan.ps1`)
Comprehensive risk assessments with Purple Knight-style scoring.

```powershell
# Curated production scan
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\latest

# Wide LDAP coverage (hundreds of checks)
.\Invoke-ADSuiteScan.ps1 `
    -ChecksJsonPath .\checks.generated.json `
    -ChecksOverridesPath .\checks.overrides.phaseB-complete.json `
    -OutputDirectory .\out\latest

# Category-scoped scan
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -Category Kerberos_Security

# Specific checks only
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -IncludeCheckId KRB-002,ACC-034
```

**Outputs:**
- `scan-results.json` - Complete scan data with scores and findings
- `findings.csv` - Flattened CSV for spreadsheet analysis
- `report.html` - HTML summary with dashboard link

**Use Cases:** Full audits, compliance reporting, scheduled scans, risk trending

### Mode 3: UI Dashboard (`ui/dashboard.html`)
Interactive visual analysis and scan planning.

```powershell
# 1. Run a scan
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\latest

# 2. Open dashboard
start .\ui\dashboard.html

# 3. In browser: Load out\latest\scan-results.json
# 4. Optional: Load catalog-summary.json for scan planner
```

**Features:**
- Global risk score (0-100) with risk band
- Category breakdown and top 10 risks
- Sortable, filterable checks table
- Expandable finding details
- Scan planner (generates commands)
- 100% client-side (no data leaves browser)

**Use Cases:** Executive reporting, interactive analysis, scan planning

## 🤖 Automated Testing

### Run Full Scenario Test
```powershell
.\Test-RealWorldScenario.ps1 -ServerName kingslanding.sevenkingdoms.local
```

### Batch Execution
```powershell
$checks = @('ACC-001', 'ACC-034', 'KRB-002', 'ACC-037')
foreach ($check in $checks) {
    .\adsi.ps1 -CheckId $check -ServerName dc01.domain.local -CompactOutput
}
```

### CI/CD Security Gate
```powershell
$criticalChecks = @('KRB-002', 'ACC-034', 'ACC-037')
foreach ($check in $criticalChecks) {
    .\adsi.ps1 -CheckId $check -ServerName dc01.domain.local -Quiet -FailOnFindings
    if ($LASTEXITCODE -eq 3) {
        Write-Host "[FAIL] $check found security issues!"
        exit 1
    }
}
```

## 📚 Documentation

### Essential Documentation
- **[README.md](README.md)** - This file (main documentation)
- **[COMPLETE_ARCHITECTURE.md](COMPLETE_ARCHITECTURE.md)** - Complete system architecture
- **[EXECUTION_MODES_QUICK_REFERENCE.md](EXECUTION_MODES_QUICK_REFERENCE.md)** - Quick reference for all modes
- **[QUICK_START_GUIDE.md](QUICK_START_GUIDE.md)** - Complete command reference
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions

### Advanced Topics
- **[docs/RISK_PACK.md](docs/RISK_PACK.md)** - Risk pack contract and engine types (field-level rules)
- **[docs/COVERAGE.md](docs/COVERAGE.md)** - Rule pack coverage documentation
- **[docs/LAB_VALIDATION.md](docs/LAB_VALIDATION.md)** - Lab validation procedures
- **[docs/REVIEW_CHECKLIST.md](docs/REVIEW_CHECKLIST.md)** - Risk rule promotion checklist
- **[ui/README.md](ui/README.md)** - UI dashboard documentation

## 🎯 Use Cases

1. **Penetration Testing** - Enumerate AD without ActiveDirectory module
2. **Security Auditing** - Comprehensive AD security assessment with risk scoring
3. **Compliance Checking** - Validate security configurations across categories
4. **GOAD Lab Training** - Practice AD enumeration techniques
5. **CI/CD Integration** - Automated security gates with exit codes
6. **Incident Response** - Quick AD security posture assessment
7. **Red Team Operations** - Identify attack paths (Kerberoasting, delegation, etc.)
8. **Blue Team Defense** - Detect misconfigurations and vulnerabilities
9. **Executive Reporting** - Visual dashboards with risk scores
10. **Scheduled Audits** - Automated weekly/monthly assessments

## 🔧 Requirements

- **PowerShell:** 5.1 or higher
- **Platform:** Windows
- **Framework:** .NET Framework (built-in)
- **Dependencies:** None (pure ADSI implementation)
- **Permissions:** Domain user account (some checks require elevated privileges)
- **Network:** LDAP access to Active Directory (typically domain-joined machine)

**Note:** Node.js only needed for regenerating Phase B override JSON (`tools/Generate-PhaseB*.js`), not for day-to-day scanning.

## 📊 How It Works

### Catalog System (Source of Truth)

1. **`checks.json`** — Curated risk pack with real `ldap`/`filesystem` rules for production scans
2. **`checks.generated.json`** — Large legacy export (756 checks); by default all `engine: inventory` (skipped by scanner until promoted)
3. **`checks.overrides.json`** — Optional patches by check `id` (severity, engine, filters, text)
   - Auto-loaded by `Invoke-ADSuiteScan.ps1` and `adsi.ps1` if exists
4. **`checks.overrides.phaseB-complete.json`** — Bulk promotion file (661 checks)
   - Merges with `checks.generated.json` to run many checks as `ldap`
   - Excludes Phase C/D categories (Certificate_Services, Azure_AD_Integration)

### Workflow

```
1. Load catalog (checks.json or checks.generated.json)
   ↓
2. Apply defaults and overrides
   ↓
3. Validate structure (Test-ADSuiteCatalog.ps1)
   ↓
4. Filter checks (exclude engine=inventory for risk scans)
   ↓
5. Execute checks via ADSI/DirectorySearcher
   ↓
6. Calculate scores (severity-weighted)
   ↓
7. Generate outputs (JSON/CSV/HTML)
```

### Execution Modes

- **Single check:** `adsi.ps1` — One CheckId, good for debugging
- **Full scan:** `Invoke-ADSuiteScan.ps1` — All non-inventory checks, scoring, reports
- **UI:** `ui/dashboard.html` — Load scan-results.json for interactive analysis

### Engine Types

- **`ldap` / `filesystem` / `registry`** — Scanner attempts them (registry may stub)
- **`inventory`** — NOT part of risk scan; documentation/listing only

## 🔍 Available Checks

### View All Checks
```powershell
$config = Get-Content .\checks.generated.json | ConvertFrom-Json
$config.checks | Select-Object id, name, category | Format-Table -AutoSize
```

### Search Checks
```powershell
# By keyword
$config.checks | Where-Object { $_.name -like "*Kerberos*" }

# By category
$config.checks | Where-Object { $_.category -eq "Kerberos_Security" }
```

### Check Categories
```powershell
$config.checks | Group-Object category | Sort-Object Count -Descending
```

## 🎓 Examples

### Example 1: Quick Security Assessment (Single Check Runner)
```powershell
# Top 5 critical checks
$checks = @('ACC-001', 'ACC-034', 'KRB-002', 'ACC-037', 'CERT-002')
foreach ($c in $checks) {
    Write-Host "`n=== $c ===" -ForegroundColor Cyan
    .\adsi.ps1 -CheckId $c -ServerName dc01.domain.local -CompactOutput
}
```

### Example 2: Full Risk Assessment (Batch Scanner)
```powershell
# Complete AD security audit with risk scoring
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\latest

# Open dashboard for analysis
start .\ui\dashboard.html
# Then load .\out\latest\scan-results.json in browser
```

### Example 3: Category-Scoped Audit (Batch Scanner)
```powershell
# Focus on Kerberos and Certificate Services
.\Invoke-ADSuiteScan.ps1 `
    -ChecksJsonPath .\checks.json `
    -Category Kerberos_Security,Certificate_Services `
    -OutputDirectory .\out\kerberos-adcs
```

### Example 4: CI/CD Security Gate (Single Check Runner)
```powershell
# Fail build if critical vulnerabilities found
$criticalChecks = @('KRB-002', 'ACC-034', 'ACC-037', 'CERT-002')
foreach ($check in $criticalChecks) {
    .\adsi.ps1 -CheckId $check -Quiet -FailOnFindings
    if ($LASTEXITCODE -eq 3) {
        Write-Error "Critical security issue: $check"
        exit 1
    }
}
```

### Example 5: Scheduled Weekly Audit (Batch Scanner)
```powershell
# Schedule this script to run weekly
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputPath = "\\share\audits\$timestamp"

.\Invoke-ADSuiteScan.ps1 `
    -ChecksJsonPath .\checks.json `
    -OutputDirectory $outputPath

# Email the report.html to security team
Send-MailMessage -To "security@company.com" `
    -Subject "Weekly AD Security Audit - $timestamp" `
    -Attachments "$outputPath\report.html" `
    -Body "See attached report. Open dashboard for interactive analysis."
```

### Example 6: Interactive Exploration (Single Check Runner)
```powershell
# View in grid
.\adsi.ps1 -CheckId ACC-001 -PassThru | Out-GridView

# View specific properties
.\adsi.ps1 -CheckId ACC-001 -PassThru | 
    Select-Object name, samAccountName, distinguishedName | 
    Format-Table -AutoSize
```

## 🔐 Security Considerations

- **Credentials:** Script uses current user's credentials by default
- **Permissions:** Some checks require domain admin or equivalent
- **Logging:** All queries are logged in AD event logs
- **Network:** LDAP traffic is unencrypted by default (use LDAPS for sensitive environments)
- **Scope:** Queries can return large result sets; use appropriate filters

## 🐛 Troubleshooting

### Common Issues

**Issue:** Output shows metadata instead of AD properties  
**Solution:** Use `-CompactOutput` parameter
```powershell
.\adsi.ps1 -CheckId ACC-001 -CompactOutput
```

**Issue:** LDAP connection failed  
**Solution:** Specify ServerName explicitly
```powershell
.\adsi.ps1 -CheckId ACC-001 -ServerName dc01.domain.local
```

**Issue:** Execution policy error  
**Solution:** Set execution policy
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

**Issue:** Batch scanner skips all checks  
**Solution:** Use `checks.json` (not `checks.generated.json` alone, which has all `engine: inventory`)
```powershell
# Curated production scan
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json

# OR use generated + Phase B overrides for wide coverage
.\Invoke-ADSuiteScan.ps1 `
    -ChecksJsonPath .\checks.generated.json `
    -ChecksOverridesPath .\checks.overrides.phaseB-complete.json
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for complete troubleshooting guide.

## 📈 Performance

- **Single Check:** 200-700ms
- **10 Checks:** 2-7 seconds
- **100 Results:** ~500ms
- **1,000 Results:** 1-2 seconds
- **10,000 Results:** 5-10 seconds (with paging)

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add your checks to `checks.json`
4. Test thoroughly
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- GOAD (Game of Active Directory) project for the vulnerable lab environment
- Active Directory security research community
- PowerShell and .NET Framework teams

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/mudigolambharath256-max/AD_SUITE_TESTING/issues)
- **Documentation:** See docs folder
- **Examples:** See REAL_WORLD_SCENARIO_TEST.md

## 🔗 Links

- **Repository:** https://github.com/mudigolambharath256-max/AD_SUITE_TESTING
- **Branch:** mod
- **GOAD Lab:** https://github.com/Orange-Cyberdefense/GOAD

## 📊 Statistics

- **Total Checks:** 756 (in checks.generated.json)
- **Curated Checks:** 7 (in checks.json, production-ready)
- **Phase B Promoted:** 661 (in checks.overrides.phaseB-complete.json)
- **Categories:** 26
- **Code Lines:** 19,000+
- **Module Functions:** 14 exported functions
- **Documentation:** 9 comprehensive guides
- **Execution Modes:** 3 (single check, batch scanner, UI dashboard)

## 🔄 Current Status

### Completed
- ✅ Pure ADSI implementation (no ActiveDirectory module)
- ✅ Three execution modes (single check, batch scanner, UI dashboard)
- ✅ Purple Knight-style risk scoring (0-100)
- ✅ 756 checks across 26 categories
- ✅ Phase B metadata and bulk promotion (661 checks)
- ✅ JSON/CSV/HTML output formats
- ✅ Interactive browser dashboard
- ✅ Catalog validation and override system
- ✅ Comprehensive documentation

### Phase Status
- ✅ **Phase A:** Curated inventory rows (checks.json)
- ✅ **Phase B:** Vulnerability-style metadata + bulk LDAP promotion (661 checks, excludes CERT/Azure)
- ⏳ **Phase C/D:** Certificate_Services and Azure_AD_Integration categories (not yet promoted in bulk file)

---

**Made with ❤️ for the AD security community**

**⭐ Star this repo if you find it useful!**

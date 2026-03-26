# AD Suite - Complete Architecture Documentation

## 📐 System Overview

AD Suite is a comprehensive Active Directory security auditing framework with **three distinct execution modes** designed for different use cases:

1. **Single Check Runner** (`adsi.ps1`) - Interactive exploration and targeted checks
2. **Batch Scanner** (`Invoke-ADSuiteScan.ps1`) - Full risk assessments with scoring
3. **UI Dashboard** (`ui/dashboard.html`) - Visual analysis and scan planning

---

## 🎯 Execution Modes

### Mode 1: Single Check Runner (`adsi.ps1`)

**Purpose:** Execute individual security checks interactively or in automation pipelines.

**Use Cases:**
- Quick security checks during penetration testing
- Targeted investigation of specific vulnerabilities
- CI/CD security gates
- Learning and exploration
- Debugging check definitions

**Features:**
- Fast execution (200-700ms per check)
- Multiple output formats (table, compact, pipeline)
- Exit codes for automation
- No report generation overhead
- Direct LDAP query execution

**Example:**
```powershell
# Interactive exploration
.\adsi.ps1 -CheckId KRB-002 -CompactOutput

# CI/CD security gate
.\adsi.ps1 -CheckId ACC-034 -Quiet -FailOnFindings
if ($LASTEXITCODE -eq 3) { exit 1 }

# Pipeline processing
.\adsi.ps1 -CheckId ACC-001 -PassThru | Export-Csv results.csv
```

**Architecture:**
```
User → adsi.ps1 → Load single check → Execute LDAP query → Format output → Exit
```

---

### Mode 2: Batch Scanner (`Invoke-ADSuiteScan.ps1`)

**Purpose:** Execute comprehensive risk assessments across all security checks with scoring and reporting.

**Use Cases:**
- Purple Knight / Ping Castle-style full AD assessments
- Scheduled security audits
- Compliance reporting
- Risk scoring and trending
- Category-scoped assessments

**Features:**
- Runs all checks in catalog (or filtered by category/ID)
- Global risk scoring (0-100 scale)
- Severity-weighted findings
- Multiple output formats (JSON, CSV, HTML)
- Category aggregation
- Error handling and continuation
- Metadata tracking

**Example:**
```powershell
# Full risk assessment
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\latest

# Category-scoped scan
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -Category Kerberos_Security,Certificate_Services

# Specific checks only
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -IncludeCheckId KRB-002,ACC-034,CERT-002
```

**Architecture:**
```
User → Invoke-ADSuiteScan.ps1
  ↓
Load catalog + overrides
  ↓
Filter checks (category/include/exclude)
  ↓
Validate catalog integrity
  ↓
Execute all checks sequentially
  ↓
Calculate scores (per-check + global)
  ↓
Generate outputs:
  - scan-results.json (complete data)
  - findings.csv (flattened findings)
  - report.html (summary report)
  ↓
Exit
```

**Output Files:**
- `scan-results.json` - Complete scan data with metadata, scores, findings
- `findings.csv` - Flattened CSV of all findings for spreadsheet analysis
- `report.html` - HTML summary report with link to dashboard

---

### Mode 3: UI Dashboard (`ui/dashboard.html`)

**Purpose:** Visual analysis of scan results with interactive filtering and scan planning.

**Use Cases:**
- Executive reporting and visualization
- Interactive finding exploration
- Category-based filtering
- Scan planning and command generation
- Offline analysis (no data leaves browser)

**Features:**
- Purple Knight / Ping Castle-style dashboard
- Global risk score visualization
- Category breakdown table
- Top 10 risks by score
- Sortable, filterable checks table
- Expandable finding details
- Scan planner (generates commands)
- Export filtered results
- Print-friendly layout
- 100% client-side (no uploads)

**Example:**
```powershell
# 1. Run scan
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory .\out\latest

# 2. Open dashboard
start .\ui\dashboard.html

# 3. Load scan-results.json from browser
# 4. Optionally load catalog-summary.json for scan planner
```

**Architecture:**
```
Browser → dashboard.html
  ↓
User loads scan-results.json
  ↓
JavaScript parses JSON
  ↓
Renders:
  - Global risk score cards
  - Category breakdown table
  - Top 10 risks
  - Category filter chips
  - All checks table with drill-down
  ↓
User interactions:
  - Filter by category
  - Sort columns
  - Expand finding details
  - Export filtered JSON
  - Plan next scan
```

---

## 📊 Check Catalog Hierarchy

The framework uses a three-tier catalog system:

### 1. `checks.json` (Production Risk Pack)
**Role:** Curated, production-ready security checks

**Characteristics:**
- Manually reviewed and validated
- Complete metadata (description, remediation, references)
- Appropriate severity ratings
- `engine: ldap` or `engine: filesystem`
- Used for risk assessments

**Example:**
```json
{
  "schemaVersion": 1,
  "meta": {
    "packName": "AD Suite Core",
    "packVersion": "1.0.0"
  },
  "defaults": {
    "searchScope": "Subtree",
    "pageSize": 1000
  },
  "checks": [
    {
      "id": "KRB-002",
      "name": "AS-REP Roastable Accounts",
      "category": "Kerberos_Security",
      "engine": "ldap",
      "severity": "high",
      "description": "Accounts with DONT_REQ_PREAUTH flag...",
      "remediation": "Remove DONT_REQ_PREAUTH flag...",
      "references": ["https://attack.mitre.org/techniques/T1558/004/"]
    }
  ]
}
```

### 2. `checks.overrides.json` (Patches)
**Role:** Override specific fields without duplicating full definitions

**Characteristics:**
- Partial check objects keyed by `id`
- Non-null fields override base catalog
- Used to promote checks from inventory to production
- Adjust severity, fix filters, add metadata

**Example:**
```json
{
  "schemaVersion": 1,
  "checks": [
    {
      "id": "KRBTGT_LAST_PW_CHANGE",
      "engine": "ldap",
      "severity": "medium",
      "description": "krbtgt account password age check"
    }
  ]
}
```

### 3. `checks.generated.json` (Full Inventory)
**Role:** Complete LDAP stub listing from legacy script migration

**Characteristics:**
- 756 checks auto-generated from legacy scripts
- All checks default to `engine: inventory`
- Reference catalog, not production risk pack
- Individual checks promoted via overrides

**Load Order:**
```
1. Read base catalog (checks.json or checks.generated.json)
2. Merge defaults into each check
3. Apply overrides by id (checks.overrides.json)
4. Validate catalog integrity
5. Filter by engine (exclude inventory for risk scans)
```

---

## 🔧 Engine Types

| Engine | Risk Scan | Description | Implementation |
|--------|-----------|-------------|----------------|
| `ldap` | ✅ Included | LDAP query; each row is a finding | `Invoke-ADSuiteLdapCheck` |
| `filesystem` | ✅ Included | Host-accessible paths (e.g. SYSVOL) | `Invoke-ADSuiteFilesystemCheck` |
| `registry` | ✅ Included | Registry checks (stub, not implemented) | Returns error |
| `inventory` | ❌ Excluded | Documentation/listing only | Skipped in risk scans |

**Key Point:** `checks.generated.json` has all checks as `engine: inventory` by default. To use a check in risk scans, promote it to `ldap` or `filesystem` via `checks.overrides.json` or copy to `checks.json`.

---

## 📁 Project Structure

```
AD_SUITE_TESTING/
├── adsi.ps1                          # Single check runner
├── Invoke-ADSuiteScan.ps1            # Batch scanner
├── Show-CheckResults.ps1             # Results viewer
├── Test-ADSuiteCatalog.ps1           # Catalog validator
├── Test-RealWorldScenario.ps1        # Automated test script
│
├── Modules/
│   └── ADSuite.Adsi.psm1             # LDAP/ADSI helper functions
│
├── checks.json                       # Production risk pack (curated)
├── checks.overrides.json             # Check patches/overrides
├── checks.overrides.EXAMPLE.json     # Example overrides
├── checks.generated.json             # Full inventory (756 checks)
│
├── ui/
│   ├── dashboard.html                # Interactive dashboard
│   ├── catalog-summary.json          # Catalog summary for planner
│   └── README.md                     # UI documentation
│
├── tools/
│   ├── Export-ChecksJsonFromLegacyScripts.ps1  # Legacy migration
│   ├── Export-ADSuiteCatalogSummary.ps1        # Catalog summary generator
│   ├── Deduplicate-CheckIdsInCatalog.ps1       # Deduplication tool
│   ├── Test-DuplicateCheckIds.ps1              # Duplicate ID tester
│   └── Set-GeneratedCatalogInventoryDefault.ps1 # Reset to inventory
│
├── docs/
│   ├── COVERAGE.md                   # Rule pack coverage
│   ├── LAB_VALIDATION.md             # Lab validation procedures
│   ├── REVIEW_CHECKLIST.md           # Risk rule promotion checklist
│   └── RISK_PACK.md                  # Risk pack contract
│
├── README.md                         # Main documentation
├── QUICK_START_GUIDE.md              # Command reference
├── REAL_WORLD_SCENARIO_TEST.md       # Detailed test scenario
├── EXECUTION_SUMMARY.md              # Framework analysis
├── TROUBLESHOOTING.md                # Common issues
├── FINAL_SUMMARY.md                  # Project summary
└── COMPLETE_ARCHITECTURE.md          # This document
```

---

## 🔄 Complete Data Flow (Batch Scanner)

```
┌─────────────────────────────────────────────────────────────┐
│ USER COMMAND                                                │
│ .\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json    │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ LOAD CATALOG                                                │
│ • Read checks.json                                          │
│ • Auto-load checks.overrides.json if exists                │
│ • Merge defaults into each check                           │
│ • Apply overrides by id                                    │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ VALIDATE CATALOG (unless -SkipCatalogValidation)           │
│ • Check for duplicate IDs                                   │
│ • Validate required fields per engine                      │
│ • Warn about missing severity/description                  │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ FILTER CHECKS                                               │
│ • Exclude engine=inventory                                  │
│ • Apply -Category filter (if specified)                    │
│ • Apply -IncludeCheckId filter (if specified)              │
│ • Apply -ExcludeCheckId filter (if specified)              │
│ • Check for duplicates in final list                       │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ CONNECT TO AD                                               │
│ • Get-ADSuiteRootDse                                        │
│ • Retrieve naming contexts                                 │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ EXECUTE CHECKS (Sequential)                                │
│ For each check:                                             │
│   • Determine engine (ldap/filesystem/registry)            │
│   • Execute check via appropriate function                 │
│   • Collect findings, errors, duration                     │
│   • Continue on error (unless -StopOnFirstError)           │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ CALCULATE SCORES                                            │
│ Per check:                                                  │
│   • weight = severity weight (info=1 ... critical=5)       │
│   • capped = min(FindingCount, FindingCapPerCheck)         │
│   • CheckScore = weight × capped × scoreWeight             │
│ Global:                                                     │
│   • globalRaw = sum(CheckScore)                            │
│   • globalScore = min(100, ceil(globalRaw / Normalizer))   │
│   • globalRiskBand = Low/Moderate/High/Critical            │
│ By Category:                                                │
│   • scoreByCategory = sum(CheckScore) per category         │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ AGGREGATE STATISTICS                                        │
│ • checksRun, checksWithFindings, checksWithErrors          │
│ • totalFindings                                             │
│ • byCategory breakdown (checks, withFindings, errors)      │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ GENERATE OUTPUTS                                            │
│ 1. scan-results.json                                        │
│    • Complete scan document                                 │
│    • Metadata, aggregate, byCategory, results              │
│    • All findings with full details                        │
│                                                             │
│ 2. findings.csv                                             │
│    • Flattened findings for spreadsheet analysis           │
│    • Uniform columns across all findings                   │
│                                                             │
│ 3. report.html                                              │
│    • HTML summary report                                    │
│    • Link to dashboard for interactive analysis            │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ EXIT                                                        │
│ • Exit code 0 (success)                                     │
│ • Exit code 1 (error)                                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Choosing the Right Mode

| Scenario | Recommended Mode | Command |
|----------|------------------|---------|
| Quick check during pentest | Single Check Runner | `.\adsi.ps1 -CheckId KRB-002 -CompactOutput` |
| Full AD security assessment | Batch Scanner | `.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json` |
| Category-specific audit | Batch Scanner | `.\Invoke-ADSuiteScan.ps1 -Category Kerberos_Security` |
| CI/CD security gate | Single Check Runner | `.\adsi.ps1 -CheckId ACC-034 -Quiet -FailOnFindings` |
| Executive reporting | Batch Scanner + UI | Run scan, open dashboard |
| Learning/exploration | Single Check Runner | `.\adsi.ps1 -CheckId ACC-001 -CompactOutput` |
| Scheduled audits | Batch Scanner | Schedule `Invoke-ADSuiteScan.ps1` |
| Offline analysis | UI Dashboard | Load existing scan-results.json |
| Scan planning | UI Dashboard | Load catalog-summary.json, use planner |

---

## 🔐 Risk Scoring System

### Per-Check Score Calculation

```
1. Severity Weight:
   - info     = 1
   - low      = 2
   - medium   = 3
   - high     = 4
   - critical = 5

2. Capped Findings:
   cappedFindings = min(FindingCount, FindingCapPerCheck)
   Default FindingCapPerCheck = 10

3. Check Score:
   CheckScore = severityWeight × cappedFindings × scoreWeight
   Default scoreWeight = 1 (can be adjusted per check)
```

### Global Score Calculation

```
1. Raw Score:
   globalRaw = sum(CheckScore) for all checks

2. Normalized Score (0-100):
   globalScore = min(100, ceil(globalRaw / ScoringNormalizer))
   Default ScoringNormalizer = 5

3. Risk Band:
   0-25   = Low
   26-50  = Moderate
   51-75  = High
   76-100 = Critical
```

### Category Scores

```
scoreByCategory[category] = sum(CheckScore) for checks in category
```

**Example:**
```
Check: KRB-002 (AS-REP Roastable)
- Severity: high (weight = 4)
- Findings: 15
- Capped: min(15, 10) = 10
- ScoreWeight: 1
- CheckScore: 4 × 10 × 1 = 40

Check: ACC-001 (Privileged Users)
- Severity: medium (weight = 3)
- Findings: 5
- Capped: min(5, 10) = 5
- ScoreWeight: 1
- CheckScore: 3 × 5 × 1 = 15

GlobalRaw: 40 + 15 = 55
GlobalScore: min(100, ceil(55 / 5)) = 11
RiskBand: Low (0-25)
```

---

## 🛠️ Tools and Utilities

### Catalog Management

**Export-ADSuiteCatalogSummary.ps1**
- Generates `catalog-summary.json` for UI dashboard scan planner
- Groups checks by category
- Includes check counts and engine types

**Deduplicate-CheckIdsInCatalog.ps1**
- Removes duplicate check IDs from catalog
- Keeps first occurrence

**Test-DuplicateCheckIds.ps1**
- Reports duplicate check IDs without modifying catalog

**Set-GeneratedCatalogInventoryDefault.ps1**
- Resets all checks in generated catalog to `engine: inventory`
- Used after bulk editing

### Legacy Migration

**Export-ChecksJsonFromLegacyScripts.ps1**
- Parses legacy PowerShell scripts
- Extracts LDAP filters, search bases, properties
- Generates `checks.generated.json`
- Fixes Unicode escape sequences

### Validation

**Test-ADSuiteCatalog.ps1**
- Validates catalog structure
- Checks for duplicate IDs
- Validates required fields per engine
- Reports warnings for missing metadata

---

## 📊 Output Formats

### scan-results.json Structure

```json
{
  "schemaVersion": 1,
  "meta": {
    "packName": "AD Suite Core",
    "packVersion": "1.0.0",
    "scanTimeUtc": "2024-03-27T10:30:00Z",
    "serverName": "dc01.domain.local",
    "defaultNamingContext": "DC=domain,DC=local",
    "checksJsonPath": "C:\\path\\to\\checks.json",
    "checksRun": 50,
    "scoringNormalizer": 5,
    "findingCapPerCheck": 10
  },
  "aggregate": {
    "checksRun": 50,
    "checksWithFindings": 12,
    "checksWithErrors": 0,
    "totalFindings": 87,
    "globalRaw": 145,
    "globalScore": 29,
    "globalRiskBand": "Moderate",
    "scoreByCategory": {
      "Kerberos_Security": 40,
      "Access_Control": 35,
      "Certificate_Services": 30
    }
  },
  "byCategory": {
    "Kerberos_Security": {
      "checks": 10,
      "withFindings": 3,
      "errors": 0
    }
  },
  "results": [
    {
      "CheckId": "KRB-002",
      "CheckName": "AS-REP Roastable Accounts",
      "Category": "Kerberos_Security",
      "Severity": "high",
      "Description": "...",
      "FindingCount": 5,
      "Result": "Fail",
      "DurationMs": 450,
      "Error": null,
      "ExitCode": 0,
      "CheckScore": 20,
      "Findings": [
        {
          "name": "user1",
          "samAccountName": "user1",
          "distinguishedName": "CN=user1,CN=Users,DC=domain,DC=local",
          "userAccountControl": "4260352"
        }
      ],
      "SourcePath": "Kerberos_Security/KRB-002_AS-REP_Roastable.ps1",
      "Remediation": "Remove DONT_REQ_PREAUTH flag",
      "References": ["https://attack.mitre.org/techniques/T1558/004/"],
      "ScoreWeight": 1
    }
  ]
}
```

---

## 🎓 Best Practices

### For Single Check Runner
- Use `-CompactOutput` for clean console output
- Use `-PassThru` for pipeline processing
- Use `-FailOnFindings` in CI/CD
- Use `-Quiet` to suppress host output

### For Batch Scanner
- Use `checks.json` (curated) for production risk scans
- Use `-Category` to scope scans to specific areas
- Use `-IncludeCheckId` for targeted assessments
- Review catalog warnings before production use
- Schedule regular scans for trending

### For UI Dashboard
- Generate `catalog-summary.json` after editing checks
- Use scan planner to generate commands
- Filter by category for focused analysis
- Export filtered results for sharing
- Keep scan-results.json secure (contains sensitive data)

### For Catalog Management
- Keep `checks.json` curated and reviewed
- Use `checks.overrides.json` for patches
- Don't use `checks.generated.json` directly for risk scans
- Validate catalog with `Test-ADSuiteCatalog.ps1`
- Document severity ratings and remediation

---

## 🔗 Integration Patterns

### CI/CD Pipeline
```powershell
# Run critical checks
$checks = @('KRB-002', 'ACC-034', 'ACC-037', 'CERT-002')
foreach ($check in $checks) {
    .\adsi.ps1 -CheckId $check -Quiet -FailOnFindings
    if ($LASTEXITCODE -eq 3) {
        Write-Error "Security issue detected: $check"
        exit 1
    }
}
```

### Scheduled Audit
```powershell
# Weekly full scan
$ts = Get-Date -Format 'yyyyMMdd'
$out = "\\share\audits\$ts"
.\Invoke-ADSuiteScan.ps1 -ChecksJsonPath .\checks.json -OutputDirectory $out
```

### Incident Response
```powershell
# Quick triage
$critical = @('ACC-033', 'ACC-037', 'KRB-002')
foreach ($c in $critical) {
    .\adsi.ps1 -CheckId $c -CompactOutput | Tee-Object -FilePath "triage-$c.txt"
}
```

---

## 📈 Performance Characteristics

| Operation | Time | Notes |
|-----------|------|-------|
| Single check | 200-700ms | Depends on result count |
| 10 checks | 2-7 seconds | Sequential execution |
| 50 checks | 10-35 seconds | Full category scan |
| 756 checks | 5-15 minutes | Complete inventory |
| 100 results | ~500ms | LDAP query + formatting |
| 1,000 results | 1-2 seconds | With paging |
| 10,000 results | 5-10 seconds | Large result sets |

---

## 🎉 Summary

AD Suite provides a complete Active Directory security auditing solution with three complementary execution modes:

1. **Single Check Runner** - Fast, targeted, perfect for pentesting and CI/CD
2. **Batch Scanner** - Comprehensive risk assessments with Purple Knight-style scoring
3. **UI Dashboard** - Interactive analysis and scan planning

The three-tier catalog system (production pack, overrides, inventory) provides flexibility for both curated risk assessments and comprehensive LDAP exploration.

**Choose the right tool for the job:**
- Need quick answers? → Single check runner
- Need comprehensive assessment? → Batch scanner
- Need visual analysis? → UI dashboard
- Need all three? → You have them all!

---

**Made with ❤️ for the AD security community**

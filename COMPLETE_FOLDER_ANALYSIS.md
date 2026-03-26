# 📊 COMPLETE AD SUITE FOLDER ANALYSIS

## 🗂️ Repository Structure Overview

```
AD_SUITE/
├── 📁 .git/                          # Git repository metadata
├── 📁 docs/                          # Documentation
│   ├── COVERAGE.md                   # Check coverage tracking
│   ├── LAB_VALIDATION.md             # Lab testing procedures
│   ├── REVIEW_CHECKLIST.md           # Rule promotion checklist
│   └── RISK_PACK.md                  # Risk pack contract
├── 📁 Modules/                       # PowerShell modules
│   └── ADSuite.Adsi.psm1            # Core LDAP/ADSI module (1,132 lines)
├── 📁 tools/                         # Utility scripts
│   ├── Deduplicate-CheckIdsInCatalog.ps1
│   ├── Export-ADSuiteCatalogSummary.ps1
│   ├── Export-ChecksJsonFromLegacyScripts.ps1
│   ├── Set-GeneratedCatalogInventoryDefault.ps1
│   └── Test-DuplicateCheckIds.ps1
├── 📁 ui/                            # Web dashboard
│   ├── catalog-summary.json          # Catalog metadata
│   ├── dashboard.html                # Interactive dashboard (646 lines)
│   └── README.md                     # Dashboard documentation
├── 📄 adsi.ps1                       # Main check runner (180 lines)
├── 📄 checks.json                    # Curated risk pack (384 lines, 15 checks)
├── 📄 checks.generated.json          # Auto-generated catalog (14,590 lines, 756 checks)
├── 📄 checks.overrides.json          # Check overrides
├── 📄 checks.overrides.EXAMPLE.json  # Override example
├── 📄 Invoke-ADSuiteScan.ps1         # Batch scanner (353 lines)
├── 📄 Test-ADSuiteCatalog.ps1        # Catalog validator (148 lines)
├── 📄 Test-RealWorldScenario.ps1     # Scenario test script (367 lines)
├── 📄 EXECUTION_SUMMARY.md           # Execution summary (341 lines)
├── 📄 QUICK_START_GUIDE.md           # Quick start guide (576 lines)
├── 📄 REAL_WORLD_SCENARIO_TEST.md    # Scenario documentation (504 lines)
├── 📄 TROUBLESHOOTING.md             # Troubleshooting guide (472 lines)
└── 📄 Scripts checks.txt             # Check inventory (5,290 lines)
```

---

## 📈 File Statistics

### Total Repository Metrics
- **Total Files:** 28 code/documentation files
- **Total Lines:** 25,000+ lines of code and documentation
- **Total Size:** ~1.2 MB
- **Languages:** PowerShell, JSON, HTML, Markdown

### Breakdown by Type

| Type | Files | Lines | Size | Purpose |
|------|-------|-------|------|---------|
| PowerShell Scripts (.ps1) | 9 | 1,738 | 68 KB | Execution and utilities |
| PowerShell Modules (.psm1) | 1 | 1,132 | 44 KB | Core LDAP functionality |
| JSON Configuration (.json) | 6 | 15,180 | 973 KB | Check definitions |
| Markdown Documentation (.md) | 11 | 2,908 | 96 KB | Guides and docs |
| HTML Dashboard (.html) | 1 | 646 | 25 KB | Interactive UI |
| Text Files (.txt) | 1 | 5,290 | 124 KB | Check inventory |

---

## 🎯 Core Components Deep Dive

### 1. Main Execution Scripts

#### adsi.ps1 (180 lines)
**Purpose:** Single check runner with ADSI/DirectorySearcher

**Key Features:**
- Runs individual LDAP checks by CheckId
- Pure ADSI implementation (no AD module required)
- Multiple output modes: Interactive, PassThru, Quiet, CompactOutput
- CI/CD integration with FailOnFindings
- Exit codes: 0 (success), 1 (error), 2 (wrong engine), 3 (findings detected)

**Parameters:**
- `-CheckId` (required) - Check identifier
- `-ServerName` - Target DC
- `-ChecksJsonPath` - Path to checks catalog
- `-PassThru` - Output objects for pipeline
- `-Quiet` - Suppress console output
- `-FailOnFindings` - Exit 3 if findings detected
- `-CompactOutput` - Show only AD properties (NEW FIX)

**Recent Fix:** Column order changed to show AD properties first, added `-CompactOutput` parameter

#### Invoke-ADSuiteScan.ps1 (353 lines)
**Purpose:** Batch scanner for comprehensive AD assessment

**Key Features:**
- Runs multiple checks in batch mode
- Supports LDAP, filesystem, and registry engines
- Generates JSON, CSV, and HTML reports
- Scoring system with risk bands
- Category filtering and check inclusion/exclusion
- Override support via checks.overrides.json

**Output Files:**
- `scan-results.json` - Complete scan data
- `findings.csv` - Flattened findings
- `report.html` - HTML report with dashboard link

**Scoring Algorithm:**
```
Per Check:
  weight = severity weight (info=1, low=2, medium=3, high=4, critical=5)
  capped = min(FindingCount, FindingCapPerCheck)  # default cap: 10
  CheckScore = weight × capped × scoreWeight

Global:
  globalRaw = sum(CheckScore)
  globalScore = min(100, ceil(globalRaw / ScoringNormalizer))  # default: 5
  globalRiskBand = Low/Medium/High/Critical based on score
```

### 2. Core Module

#### Modules/ADSuite.Adsi.psm1 (1,132 lines)
**Purpose:** Comprehensive LDAP/ADSI helper library

**Exported Functions:**

1. **Get-ADSuiteRootDse** - Connect to RootDSE
2. **Resolve-ADSuiteSearchRoot** - Resolve search base to DN
3. **Invoke-ADSuiteLdapQuery** - Execute LDAP queries
4. **Get-AdsProperty** - Extract properties from SearchResult
5. **Test-UserAccountControlMask** - UAC flag validation
6. **ConvertTo-ADSuiteFindingRow** - Format results
7. **Import-ADSuiteCatalogJson** - Load and merge catalogs
8. **Test-ADSuiteCatalogIntegrity** - Validate catalog structure
9. **Merge-ADSuiteCheckDefaults** - Merge defaults into checks
10. **Invoke-ADSuiteLdapCheck** - Execute LDAP check with metadata
11. **Invoke-ADSuiteFilesystemCheck** - Execute filesystem check
12. **Get-ADSuiteOptionalCheckMeta** - Extract check metadata
13. **Add-ADSuiteScanScores** - Calculate scan scores
14. **Export-ADSuiteHtmlReport** - Generate HTML report

**Key Capabilities:**
- DirectorySearcher-based LDAP queries
- Paged result handling (default 1000 per page)
- Multiple search base types (Domain, Configuration, Schema, Custom)
- UAC bitwise operations
- Catalog validation (duplicates, required fields)
- Filesystem checks (SYSVOL, GPO folders)
- Scoring and risk banding
- HTML report generation

### 3. Configuration Files

#### checks.json (384 lines, 15 checks)
**Purpose:** Curated production risk pack

**Structure:**
```json
{
  "schemaVersion": 1,
  "meta": {
    "packVersion": "1.0.0",
    "packName": "AD Suite Risk Pack",
    "packDateUtc": "2026-03-27T00:00:00Z"
  },
  "defaults": {
    "pageSize": 1000,
    "engine": "ldap",
    "searchScope": "Subtree"
  },
  "checks": [...]
}
``
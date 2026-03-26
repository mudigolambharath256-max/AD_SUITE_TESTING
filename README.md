# AD Suite - Active Directory Security Auditing Framework

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows-lightgrey.svg)](https://www.microsoft.com/windows)

A comprehensive Active Directory security auditing framework using pure ADSI/DirectorySearcher. No ActiveDirectory PowerShell module required!

## 🎯 Features

- ✅ **756 Security Checks** across 26 categories
- ✅ **Pure ADSI Implementation** - No AD module dependency
- ✅ **Multiple Execution Modes** - Interactive, automation, CI/CD
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

### Installation

```powershell
# Clone the repository
git clone -b mod https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
cd AD_SUITE_TESTING

# Set execution policy
Set-ExecutionPolicy Bypass -Scope Process -Force
```

### Basic Usage

```powershell
# Run a single check (local domain)
.\adsi.ps1 -CheckId ACC-001

# Run against specific DC
.\adsi.ps1 -CheckId ACC-001 -ServerName dc01.domain.local

# Run against GOAD lab
.\adsi.ps1 -CheckId KRB-002 -ServerName kingslanding.sevenkingdoms.local

# Clean output (recommended)
.\adsi.ps1 -CheckId ACC-001 -CompactOutput
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

### 1. Interactive Mode (Default)
```powershell
.\adsi.ps1 -CheckId ACC-001
```
Displays formatted table with colored output.

### 2. Compact Mode (Recommended)
```powershell
.\adsi.ps1 -CheckId ACC-001 -CompactOutput
```
Shows only AD object properties, hides metadata columns.

### 3. Automation Mode
```powershell
.\adsi.ps1 -CheckId ACC-001 -PassThru | Export-Csv results.csv -NoTypeInformation
```
Outputs objects to pipeline for further processing.

### 4. Silent Mode
```powershell
.\adsi.ps1 -CheckId ACC-001 -Quiet -PassThru
```
Suppresses host output, only returns objects.

### 5. CI/CD Mode
```powershell
.\adsi.ps1 -CheckId ACC-001 -FailOnFindings
# Exit code 0 = Pass, 3 = Findings detected
```

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

- **[QUICK_START_GUIDE.md](QUICK_START_GUIDE.md)** - Complete command reference
- **[REAL_WORLD_SCENARIO_TEST.md](REAL_WORLD_SCENARIO_TEST.md)** - Detailed scenario with 10 checks
- **[EXECUTION_SUMMARY.md](EXECUTION_SUMMARY.md)** - Framework analysis and summary
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions

## 🎯 Use Cases

1. **Penetration Testing** - Enumerate AD without ActiveDirectory module
2. **Security Auditing** - Comprehensive AD security assessment
3. **Compliance Checking** - Validate security configurations
4. **GOAD Lab Training** - Practice AD enumeration techniques
5. **CI/CD Integration** - Automated security checks
6. **Incident Response** - Quick AD security posture assessment
7. **Red Team Operations** - Identify attack paths
8. **Blue Team Defense** - Detect misconfigurations

## 🔧 Requirements

- **PowerShell:** 5.1 or higher
- **Platform:** Windows
- **Framework:** .NET Framework (built-in)
- **Dependencies:** None (pure ADSI implementation)
- **Permissions:** Domain user account (some checks require elevated privileges)

## 📊 Architecture

```
User Command
    ↓
adsi.ps1 (Parameter Validation)
    ↓
Load checks.json/checks.generated.json
    ↓
Import ADSuite.Adsi.psm1
    ↓
Get-ADSuiteRootDse (Connect to RootDSE)
    ↓
Resolve-ADSuiteSearchRoot (Get search base DN)
    ↓
Invoke-ADSuiteLdapQuery (DirectorySearcher)
    ↓
Test-UserAccountControlMask (Optional UAC filtering)
    ↓
Format Results (Table or PassThru)
    ↓
Output & Exit Code
```

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

### Example 1: Quick Security Assessment
```powershell
# Top 5 critical checks
$checks = @('ACC-001', 'ACC-034', 'KRB-002', 'ACC-037', 'CERT-002')
foreach ($c in $checks) {
    Write-Host "`n=== $c ===" -ForegroundColor Cyan
    .\adsi.ps1 -CheckId $c -ServerName dc01.domain.local -CompactOutput
}
```

### Example 2: Export All Findings
```powershell
$checks = @('ACC-001', 'ACC-014', 'ACC-034', 'KRB-002')
$allResults = @()

foreach ($check in $checks) {
    $results = .\adsi.ps1 -CheckId $check -ServerName dc01.domain.local -PassThru
    $allResults += $results
}

$allResults | Export-Csv "AD_Audit_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
```

### Example 3: Interactive Exploration
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

- **Total Checks:** 756
- **Categories:** 26
- **Code Lines:** 19,000+
- **Documentation:** 5 comprehensive guides
- **Test Scripts:** Automated testing included

## 🎯 Roadmap

- [ ] Add more ADCS vulnerability checks
- [ ] Implement parallel execution for batch checks
- [ ] Add HTML report generation
- [ ] Create PowerShell module package
- [ ] Add support for cross-forest queries
- [ ] Implement check scheduling
- [ ] Add baseline comparison features

---

**Made with ❤️ for the AD security community**

**⭐ Star this repo if you find it useful!**

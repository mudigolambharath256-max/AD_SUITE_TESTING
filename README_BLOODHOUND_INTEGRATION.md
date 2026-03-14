# AD Security Suite - BloodHound Integration Guide

**Version**: 1.0  
**Date**: March 13, 2026  
**Status**: Production Ready ✅

---

## Overview

The AD Security Suite now includes integrated BloodHound export functionality. All 762 security checks automatically export findings in BloodHound-compatible JSON format for advanced attack path analysis.

---

## Quick Start

### 1. Run a Single Check

```powershell
cd "C:\AD_Suite"
.\Access_Control\ACC-001_Privileged_Users_adminCount1\adsi.ps1
```

**Output**:
- Console output (existing functionality)
- JSON export to: `C:\ADSuite_BloodHound\SESSION_<timestamp>\ACC-001_nodes.json`

### 2. Run Multiple Checks (Same Session)

```powershell
# Set session ID (optional - auto-generated if not set)
$env:ADSUITE_SESSION_ID = "20260313_114137"

# Run checks - all use same session
.\Access_Control\ACC-001_Privileged_Users_adminCount1\adsi.ps1
.\Access_Control\ACC-002_Privileged_Groups_adminCount1\adsi.ps1
.\Access_Control\ACC-003_Privileged_Computers_adminCount1\adsi.ps1

# All results in: C:\ADSuite_BloodHound\SESSION_20260313_114137\
```

### 3. Import into BloodHound

```powershell
# Collect all JSON files
$sessionDir = "C:\ADSuite_BloodHound\SESSION_20260313_114137"
$jsonFiles = Get-ChildItem $sessionDir -Filter "*_nodes.json"

# Import via BloodHound UI or API
# BloodHound will automatically correlate nodes
```

---

## Export Format

### Directory Structure

```
C:\ADSuite_BloodHound\
└── SESSION_20260313_114137\
    ├── ACC-001_nodes.json
    ├── ACC-002_nodes.json
    ├── ACC-003_nodes.json
    ├── AUTH-001_nodes.json
    └── ...
```

### JSON Node Format

```json
{
  "nodes": [
    {
      "ObjectIdentifier": "S-1-5-21-3623811015-3361044348-30300510-500",
      "ObjectType": "User",
      "Properties": {
        "name": "Administrator",
        "distinguishedname": "CN=Administrator,CN=Users,DC=contoso,DC=com",
        "samaccountname": "Administrator",
        "domain": "CONTOSO.COM",
        "checkid": "ACC-001",
        "severity": "HIGH",
        "timestamp": "2026-03-13T11:42:00.000Z"
      }
    },
    {
      "ObjectIdentifier": "CN=Domain Admins,CN=Users,DC=contoso,DC=com",
      "ObjectType": "Group",
      "Properties": {
        "name": "Domain Admins",
        "distinguishedname": "CN=Domain Admins,CN=Users,DC=contoso,DC=com",
        "samaccountname": "Domain Admins",
        "domain": "CONTOSO.COM",
        "checkid": "ACC-002",
        "severity": "CRITICAL",
        "timestamp": "2026-03-13T11:42:15.000Z"
      }
    }
  ]
}
```

---

## Features

### Session Management
- **Auto-generated Session ID**: `YYYYMMDD_HHMMSS` format
- **Persistent across checks**: Set `$env:ADSUITE_SESSION_ID` to use same session
- **Isolated directories**: Each session in separate folder

### Object Identification
- **Primary**: ObjectSid (converted to SID string format)
- **Fallback**: DistinguishedName (if SID unavailable)
- **BloodHound Compatible**: Proper format for node correlation

### Metadata Capture
- **CheckID**: Identifies which security check found the object
- **Severity**: HIGH, CRITICAL, MEDIUM, LOW
- **Timestamp**: ISO 8601 format with milliseconds
- **Domain**: Extracted from DistinguishedName

### Error Handling
- **Try-catch blocks**: Graceful failure handling
- **Logging**: Console warnings if export fails
- **Non-blocking**: Export errors don't stop main script

---

## BloodHound Integration

### Supported Object Types
- **User**: User accounts
- **Computer**: Computer objects
- **Group**: Security groups
- **Base**: Other object types

### Node Properties
All nodes include:
- `ObjectIdentifier` - SID or DN
- `ObjectType` - User, Computer, Group, Base
- `name` - Common name
- `distinguishedname` - LDAP DN
- `samaccountname` - SAM account name
- `domain` - Domain name
- `checkid` - Security check ID
- `severity` - Finding severity
- `timestamp` - Export timestamp

### Correlation
BloodHound automatically correlates:
- Users to groups (membership)
- Users to computers (logon rights)
- Groups to groups (nesting)
- Objects to domains

---

## Configuration

### Output Directory
Default: `C:\ADSuite_BloodHound\`

To change:
```powershell
# Edit the export block in any adsi.ps1 file
# Change: $bhDir = "C:\ADSuite_BloodHound\SESSION_$env:ADSUITE_SESSION_ID"
# To: $bhDir = "D:\BloodHound_Data\SESSION_$env:ADSUITE_SESSION_ID"
```

### Session ID Format
Default: `YYYYMMDD_HHMMSS` (e.g., `20260313_114137`)

To customize:
```powershell
$env:ADSUITE_SESSION_ID = "MyCustomSession_001"
```

---

## Troubleshooting

### Export Not Creating Files

**Check 1**: Verify output directory exists
```powershell
Test-Path "C:\ADSuite_BloodHound"
```

**Check 2**: Verify write permissions
```powershell
[System.IO.File]::WriteAllText("C:\ADSuite_BloodHound\test.txt", "test")
```

**Check 3**: Check console for warnings
```
[BloodHound] Export failed: ...
```

### JSON Import Fails

**Check 1**: Validate JSON format
```powershell
Get-Content "C:\ADSuite_BloodHound\SESSION_*\*.json" | ConvertFrom-Json
```

**Check 2**: Verify ObjectIdentifier format
- Should be SID (S-1-5-...) or DN (CN=...)
- Not empty or null

**Check 3**: Check BloodHound version compatibility
- Requires BloodHound 4.0+

---

## Performance

### Export Overhead
- **Per-check**: ~100-500ms (depends on result count)
- **Per-node**: ~1-5ms
- **Typical check**: <1 second total

### Storage
- **Per-node**: ~500 bytes (JSON)
- **Per-check**: 10KB-1MB (depends on results)
- **Full session**: 50MB-500MB (typical)

### Recommendations
- Run checks during off-hours for large environments
- Use separate sessions for different check categories
- Archive old sessions to manage disk space

---

## Advanced Usage

### Batch Processing

```powershell
# Run all checks in a category
$env:ADSUITE_SESSION_ID = "AccessControl_Full_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Get-ChildItem ".\Access_Control" -Directory | ForEach-Object {
    $adsiFile = Join-Path $_.FullName "adsi.ps1"
    if (Test-Path $adsiFile) {
        Write-Host "Running: $($_.Name)"
        & $adsiFile
    }
}
```

### Incremental Collection

```powershell
# Collect data over time in same session
$env:ADSUITE_SESSION_ID = "Weekly_Scan_20260313"

# Monday
.\Access_Control\ACC-001_Privileged_Users_adminCount1\adsi.ps1

# Tuesday
.\Access_Control\ACC-002_Privileged_Groups_adminCount1\adsi.ps1

# Wednesday
.\Access_Control\ACC-003_Privileged_Computers_adminCount1\adsi.ps1

# All in same session for correlation
```

### Custom Processing

```powershell
# Post-process JSON files
$sessionDir = "C:\ADSuite_BloodHound\SESSION_20260313_114137"

Get-ChildItem $sessionDir -Filter "*_nodes.json" | ForEach-Object {
    $json = Get-Content $_.FullName | ConvertFrom-Json
    
    # Custom processing
    $json.nodes | Where-Object { $_.Properties.severity -eq 'CRITICAL' } | ForEach-Object {
        Write-Host "CRITICAL: $($_.Properties.name)"
    }
}
```

---

## Support

### Documentation
- `FINAL_COMPLETION_REPORT.md` - Implementation details
- `COMPLETE_AUDIT_FIX_SUMMARY.md` - Audit results
- `AUDIT_REPORT_BH_ELIGIBILITY_2026-03-13_114137.md` - Latest audit

### Backups
- All modifications backed up in `backups_phase4_export_*` directories
- Rollback available if needed

### Scripts
- `fix-phase4-append-bloodhound-export.ps1` - Export block implementation
- `audit-bloodhound-eligibility.ps1` - Audit and verification

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-03-13 | Initial release with BloodHound export |

---

**Status**: Production Ready ✅  
**Last Updated**: March 13, 2026 11:42  
**Support**: See documentation files

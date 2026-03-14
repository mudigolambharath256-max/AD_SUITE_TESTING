# Phase 4: BloodHound Export Block Implementation
## Implementation Roadmap

**Date**: March 13, 2026  
**Status**: Ready to Begin  
**Prerequisites**: ✅ All Complete

---

## Prerequisites Status

✅ **Phase 1 Complete** - All critical blockers resolved  
✅ **Phase 2 Complete** - High-priority fixes applied  
✅ **Phase 3 Partial** - Quality improvements in progress  
✅ **Audit Complete** - All 774 checks verified  
✅ **Backups Created** - 7 backup sets, ~150MB  

**Ready to Proceed**: YES ✅

---

## Phase 4 Overview

Append BloodHound export functionality to all adsi.ps1 scripts to enable automatic JSON export of security findings in BloodHound-compatible format.

### Goals
1. Append export block to all 762 adsi.ps1 files
2. Generate BloodHound-compatible JSON output
3. Maintain session-based organization
4. Enable incremental data collection
5. Preserve existing script functionality

---

## Export Block Design

### Core Components

1. **Session Management**
   - Environment variable: `$env:ADSUITE_SESSION_ID`
   - Format: `YYYYMMDD_HHMMSS`
   - Persistent across all checks in a session

2. **Output Structure**
   ```
   C:\ADSuite_BloodHound\
   └── SESSION_20260313_113000\
       ├── ACC-001_nodes.json
       ├── ACC-002_nodes.json
       ├── ...
       └── session_metadata.json
   ```

3. **Node Format**
   ```json
   {
     "nodes": [
       {
         "ObjectIdentifier": "S-1-5-21-...",
         "ObjectType": "User",
         "Properties": {
           "name": "Administrator",
           "distinguishedname": "CN=Administrator,CN=Users,DC=...",
           "samaccountname": "Administrator",
           "domain": "CONTOSO.COM",
           "checkid": "ACC-001",
           "severity": "HIGH",
           "timestamp": "2026-03-13T11:30:00.000Z"
         }
       }
     ]
   }
   ```

---

## Implementation Steps

### Step 1: Create Export Block Template

Create a reusable PowerShell block that:
- Checks for existing session or creates new one
- Converts $results to BloodHound JSON format
- Extracts ObjectIdentifier from objectSid
- Maps object types (User, Computer, Group, etc.)
- Writes JSON to session directory
- Handles errors gracefully

### Step 2: Create Append Script

Script to:
- Read each adsi.ps1 file
- Detect the output section (after $output creation)
- Insert export block before final output
- Preserve existing functionality
- Create backups
- Verify syntax

### Step 3: Test on Sample Files

Test export block on 5-10 representative files:
- User queries (ACC-001, USR-001)
- Computer queries (COMP-001, DC-001)
- Group queries (GRP-001)
- Complex queries (multi-object types)
- Verify JSON output format
- Verify BloodHound import

### Step 4: Batch Implementation

Apply to all 762 adsi.ps1 files:
- Run append script with backups
- Verify no syntax errors
- Spot-check 20 random files
- Run audit to verify A5 criterion

### Step 5: Integration Testing

- Run multiple checks in same session
- Verify session ID persistence
- Verify JSON aggregation
- Test BloodHound import
- Validate node relationships

---

## Export Block Template

```powershell
# ============================================================================
# BLOODHOUND EXPORT BLOCK
# ============================================================================
# Automatically export results to BloodHound-compatible JSON format
# Session-based organization for incremental data collection
# ============================================================================

try {
    # Initialize session
    if (-not $env:ADSUITE_SESSION_ID) {
        $env:ADSUITE_SESSION_ID = Get-Date -Format 'yyyyMMdd_HHmmss'
        Write-Host "[BloodHound] New session: $env:ADSUITE_SESSION_ID" -ForegroundColor Cyan
    }
    
    $bhDir = "C:\ADSuite_BloodHound\SESSION_$env:ADSUITE_SESSION_ID"
    if (-not (Test-Path $bhDir)) {
        New-Item -ItemType Directory -Path $bhDir -Force | Out-Null
    }
    
    # Convert results to BloodHound format
    if ($results -and $results.Count -gt 0) {
        $bhNodes = @()
        
        foreach ($item in $results) {
            # Extract SID as ObjectIdentifier
            $objectId = if ($item.objectSid) {
                # Convert byte array to SID string
                try {
                    (New-Object System.Security.Principal.SecurityIdentifier($item.objectSid, 0)).Value
                } catch {
                    $item.DistinguishedName
                }
            } else {
                $item.DistinguishedName
            }
            
            # Determine object type
            $objectType = if ($item.objectClass -contains 'user') { 'User' }
                         elseif ($item.objectClass -contains 'computer') { 'Computer' }
                         elseif ($item.objectClass -contains 'group') { 'Group' }
                         else { 'Base' }
            
            # Extract domain from DN
            $domain = if ($item.DistinguishedName -match 'DC=([^,]+)') {
                ($matches[1..($matches.Count-1)] -join '.').ToUpper()
            } else { 'UNKNOWN' }
            
            $bhNodes += @{
                ObjectIdentifier = $objectId
                ObjectType = $objectType
                Properties = @{
                    name = $item.Name
                    distinguishedname = $item.DistinguishedName
                    samaccountname = $item.samAccountName
                    domain = $domain
                    checkid = 'CHECK_ID_HERE'
                    severity = 'SEVERITY_HERE'
                    timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')
                }
            }
        }
        
        # Write JSON
        $bhOutput = @{ nodes = $bhNodes } | ConvertTo-Json -Depth 10
        $bhFile = Join-Path $bhDir "CHECK_ID_HERE_nodes.json"
        Set-Content -Path $bhFile -Value $bhOutput -Encoding UTF8
        
        Write-Host "[BloodHound] Exported $($bhNodes.Count) nodes to: $bhFile" -ForegroundColor Green
    }
    
} catch {
    Write-Warning "[BloodHound] Export failed: $_"
}

# ============================================================================
# END BLOODHOUND EXPORT BLOCK
# ============================================================================
```

---

## Append Script Design

```powershell
# fix-phase4-append-bloodhound-export.ps1

param([switch]$DryRun)

# For each adsi.ps1 file:
# 1. Read content
# 2. Extract CHECK_ID from filename or header
# 3. Extract SEVERITY from header
# 4. Find insertion point (after $output creation, before final output)
# 5. Insert export block with CHECK_ID and SEVERITY replaced
# 6. Backup original
# 7. Save modified file
# 8. Verify syntax
```

---

## Validation Criteria

### File-Level Validation
- ✅ Export block appended correctly
- ✅ No syntax errors
- ✅ Original functionality preserved
- ✅ CHECK_ID and SEVERITY populated
- ✅ Backup created

### Functional Validation
- ✅ JSON file created in session directory
- ✅ Valid JSON format
- ✅ ObjectIdentifier present (SID or DN)
- ✅ ObjectType correctly determined
- ✅ All required properties present
- ✅ BloodHound can import JSON

### Integration Validation
- ✅ Multiple checks use same session ID
- ✅ Session directory contains all check outputs
- ✅ No file conflicts or overwrites
- ✅ BloodHound can import entire session
- ✅ Nodes properly correlated

---

## Risk Mitigation

### Risks
1. **Syntax errors** - Could break existing scripts
2. **Performance impact** - Export adds processing time
3. **Disk space** - JSON files accumulate
4. **Session conflicts** - Multiple users/sessions

### Mitigations
1. Comprehensive backups before modification
2. Syntax validation after each append
3. Try-catch blocks around export code
4. Session-based directory isolation
5. Dry-run mode for testing
6. Rollback capability

---

## Success Criteria

✅ All 762 adsi.ps1 files have export block  
✅ No syntax errors introduced  
✅ Original functionality preserved  
✅ JSON output validates against BloodHound schema  
✅ BloodHound successfully imports data  
✅ Session management works correctly  
✅ A5 criterion passes (no duplicate exports)  

---

## Timeline Estimate

- **Step 1** (Template): 30 minutes
- **Step 2** (Append script): 1 hour
- **Step 3** (Testing): 1 hour
- **Step 4** (Batch apply): 30 minutes
- **Step 5** (Integration test): 1 hour

**Total**: ~4 hours

---

## Next Actions

1. Review and approve export block template
2. Create append script with dry-run mode
3. Test on 5 sample files
4. Review test results
5. Apply to all files
6. Run final audit
7. Integration testing
8. Documentation

---

**Status**: Ready to begin Phase 4 implementation  
**Prerequisites**: All complete  
**Estimated Completion**: 4 hours

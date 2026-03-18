# AD Security Suite - Complete Workflow Analysis

## Overview
The AD Security Suite is a comprehensive Active Directory security assessment tool with 775+ security checks across 27 categories. It features a web interface for scan management and BloodHound-compatible data generation for advanced attack path visualization.

## Project Structure

### Core Categories (27 total)
- **Access_Control** (45 checks): ACC-001 to ACC-045
- **Advanced_Security** (10 checks): ADV-001 to ADV-010  
- **Authentication** (33 checks): AUTH-001 to AUTH-033
- **Azure_AD_Integration** (42 checks): AAD-001 to AAD-042
- **Backup_Recovery** (8 checks): BCK-001 to BCK-008
- **Certificate_Services** (53 checks): CERT-001 to CERT-053
- **Computer_Management** (50 checks): CMGMT-001 to CMGMT-050
- **Computers_Servers** (60 checks): CMP-001 to CMP-060
- **Domain_Configuration** (60 checks): DCONF-001 to DCONF-060
- **Group_Policy** (40 checks): GPO-001 to GPO-040
- **Infrastructure** (30 checks): INFRA-001 to INFRA-030
- **Kerberos_Security** (50 checks): KRB-001 to KRB-050
- **LDAP_Security** (25 checks): LDAP-001 to LDAP-025
- **Miscellaneous** (137 checks): MISC-001 to MISC-137
- **Network_Security** (30 checks): NET-001 to NET-030
- **Privileged_Access** (50 checks): PRV-001 to PRV-050
- **Service_Accounts** (40 checks): SVC-001 to SVC-040
- **Users_Accounts** (70 checks): USR-001 to USR-070

### Script Organization
Each security check has **5 execution engines**:
1. **adsi.ps1** - ADSI/DirectorySearcher approach
2. **powershell.ps1** - PowerShell AD Module approach  
3. **csharp.cs** - C# DirectoryServices approach
4. **cmd.bat** - Command-line tools approach
5. **combined_multiengine.ps1** - Runs all engines and deduplicates results

## Data Flow Architecture

### 1. Web Interface → Executor
```
Frontend (React) → Backend API → Executor Service → PowerShell Scripts
```

**Key Files:**
- `frontend/src/pages/Dashboard.jsx` - Scan initiation
- `backend/routes/scan.js` - API endpoints
- `backend/services/executor.js` - Core execution engine

### 2. Script Execution Workflow
```
1. User initiates scan via web interface
2. Executor.runScan() called with parameters:
   - scanId: Unique identifier
   - checkIds: Array of checks to run (e.g., ['ACC-001', 'AUTH-002'])
   - engine: Execution engine ('adsi', 'powershell', 'combined', etc.)
   - suiteRoot: Path to AD-Suite-scripts-main/
   - domain: Target domain (optional)
   - serverIp: Domain controller IP (optional)

3. For each check:
   a. resolveScriptPath() finds the script file
   b. injectAndWriteTempScript() applies domain/IP targeting
   c. buildPsCommand() creates PowerShell execution wrapper
   d. spawn() executes the script
   e. parseScriptOutput() converts output to findings
   f. Database storage of findings

4. Export generation:
   - JSON export (findings.json)
   - CSV export (findings.csv) 
   - PDF report (report.pdf)
   - BloodHound JSON files (bloodhound/*.json)
```

### 3. BloodHound Data Generation

**Environment Variables (NEW - Fixed in this session):**
```bash
ADSUITE_SESSION_ID=<scanId>        # Enables BloodHound export
ADSUITE_OUTPUT_ROOT=<reportsDir>   # Output directory for BH files
```

**BloodHound Export Process:**
1. Scripts detect environment variables
2. Generate BloodHound-compatible JSON with proper node structure:
   ```json
   {
     "ObjectIdentifier": "S-1-5-21-...",
     "Properties": {
       "name": "USER@DOMAIN.COM",
       "domain": "DOMAIN.COM", 
       "distinguishedname": "CN=user,OU=Users,DC=domain,DC=com",
       "samaccountname": "user",
       "enabled": true,
       "adSuiteCheckId": "ACC-001",
       "adSuiteCheckName": "Privileged Users",
       "adSuiteSeverity": "high"
     },
     "Aces": [],
     "IsDeleted": false,
     "IsACLProtected": false
   }
   ```
3. Files saved to `reports/<scanId>/bloodhound/<checkId>_<timestamp>.json`

### 4. Attack Path Visualization

**Data Sources:**
1. **BloodHound JSON** (Primary) - Rich AD relationship data
2. **Scan Findings** (Fallback) - Basic finding data converted to nodes

**Visualization Pipeline:**
```
BloodHound JSON → Node/Edge Conversion → ReactFlow Graph → LLM Analysis
```

**Key Components:**
- `frontend/src/pages/AttackPath.jsx` - Main visualization interface
- `backend/routes/bloodhound.js` - BloodHound data API
- LLM integration for attack chain analysis (Anthropic Claude, OpenAI, Ollama)

## Technical Implementation Details

### PowerShell Execution Wrapper
```powershell
# For individual engines (adsi, powershell, csharp)
& 'script.ps1' | Out-Null; 
if (Get-Variable -Name output -ErrorAction SilentlyContinue) { 
    $output | ConvertTo-Json -Depth 10 -Compress 
} else { 
    @() | ConvertTo-Json 
}

# For combined engine
$r = & 'combined_multiengine.ps1'; 
$r | ConvertTo-Json -Depth 10 -Compress
```

### Script Output Format
**Standard 5-field schema:**
```json
{
  "Name": "username",
  "DistinguishedName": "CN=user,OU=Users,DC=domain,DC=com", 
  "SamAccountName": "username",
  "Domain": "domain.com",
  "Engine": "ADSI"
}
```

### Database Schema
**Findings Table:**
- id, scanId, checkId, category, checkName
- severity, riskScore, mitre
- name, distinguishedName, detailsJson
- timestamp

**Scans Table:**
- id, timestamp, engine, status
- findingCount, duration, suiteRoot

## Recent Fixes Applied

### 1. BloodHound Data Collection (This Session)
**Problem:** Scripts generate BloodHound JSON but web interface doesn't collect it
**Solution:** 
- Added environment variable setup in executor.js
- Modified Attack Path page to prioritize BloodHound data
- Added BloodHound data availability indicator

### 2. Script Execution Issues (Previous)
**Problem:** Scripts returning 0 findings due to execution wrapper issues
**Solution:**
- Fixed `isScanning()` logic to check `_activeScanId` instead of `_activeScanProcess`
- Fixed PowerShell wrapper to capture `$output` variable before `Format-List`
- Added comprehensive debug logging

### 3. Attack Path Loading (Previous)  
**Problem:** Attack Path page showing "No findings to analyze"
**Solution:**
- Added automatic findings loading when scan selected
- Fixed useEffect dependencies for proper data loading
- Added better error handling and loading states

## Workflow Summary

### Complete Scan Process:
1. **Initiation:** User selects checks and engine via web interface
2. **Execution:** Executor spawns PowerShell processes for each check
3. **Data Collection:** Scripts query AD and generate findings + BloodHound data
4. **Storage:** Findings stored in SQLite, BloodHound JSON files saved to disk
5. **Visualization:** Attack Path page loads BloodHound data for graph analysis
6. **Analysis:** LLM processes findings to identify attack chains and relationships

### Data Formats:
- **Findings:** Structured JSON with severity, MITRE mappings, AD properties
- **BloodHound:** Standard BloodHound v5 format with nodes, edges, ACEs
- **Exports:** JSON, CSV, PDF reports + BloodHound JSON files

### Integration Points:
- **BloodHound CE/Legacy:** Push findings via API
- **MITRE ATT&CK:** Technique mappings in findings
- **LLM Analysis:** Claude, OpenAI, Ollama for attack path identification

## Next Steps for Enhanced Visualization

1. **Advanced Graph Features:**
   - Implement proper BloodHound-style node relationships
   - Add Cypher query interface for complex queries
   - Create attack path highlighting and shortest path algorithms

2. **Enhanced Data Processing:**
   - Parse group memberships for MemberOf relationships
   - Extract ACL data for permission relationships  
   - Implement trust relationship mapping

3. **Visualization Improvements:**
   - Add node clustering by domain/OU
   - Implement attack technique overlays
   - Create interactive timeline for attack progression

The AD Security Suite now has a complete data pipeline from script execution through BloodHound-compatible visualization, enabling comprehensive Active Directory security assessment and attack path analysis.
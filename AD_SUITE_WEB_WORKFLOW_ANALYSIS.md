# AD Security Suite Web Application - Complete Workflow Analysis

## **Architecture Overview**

The AD Security Suite is a full-stack web application that orchestrates Active Directory security scanning through a modern React frontend and Node.js backend, integrating with PowerShell/ADSI scripts for AD enumeration.

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERFACE                            │
│                    (React + Vite Frontend)                       │
└────────────────────────┬────────────────────────────────────────┘
                         │ HTTP/REST API
                         │ Server-Sent Events (SSE)
┌────────────────────────▼────────────────────────────────────────┐
│                     EXPRESS BACKEND                              │
│                  (Node.js + SQLite)                              │
└────────────────────────┬────────────────────────────────────────┘
                         │ Child Process Spawn
                         │ PowerShell/CMD/C# Execution
┌────────────────────────▼────────────────────────────────────────┐
│                  AD SECURITY SCRIPTS                             │
│         (PowerShell, ADSI, C#, CMD - 2,258 scripts)             │
└────────────────────────┬────────────────────────────────────────┘
                         │ LDAP/ADSI Queries
                         │ Active Directory APIs
┌────────────────────────▼────────────────────────────────────────┐
│                  ACTIVE DIRECTORY                                │
│              (Domain Controllers, LDAP)                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## **Complete Workflow: From User Click to Results**

### **Phase 1: Application Initialization**

**1.1 Frontend Startup**
```
User opens browser → http://localhost:5173
├─ Vite dev server loads React app
├─ App.jsx initializes routing
├─ Health check: GET /api/health
│  └─ Backend returns: status, suiteRoot, dbSize
├─ Load categories: GET /api/categories
│  └─ Returns 27 security categories with check counts
└─ Initialize Zustand stores (app state, findings)
```

**1.2 Backend Startup**
```
npm start → node server.js
├─ Initialize Express server (port 3000)
├─ Load middleware: CORS, Helmet, JSON parser
├─ Initialize SQLite database (ad-suite.db)
│  ├─ Create tables: scans, findings, schedules, settings
│  └─ Run migrations (add domain, server_ip columns)
├─ Mount API routes:
│  ├─ /api/scan → Scan execution & diagnostics
│  ├─ /api/reports → Report generation
│  ├─ /api/integrations → BloodHound/ADExplorer
│  ├─ /api/schedules → Scheduled scans
│  └─ /api/settings → Configuration
└─ Attach WebSocket terminal server (PowerShell remote)
```

---

### **Phase 2: User Configures Scan**

**2.1 Settings Configuration**
```
User navigates to Settings page
├─ GET /api/settings/suiteRoot
│  └─ Returns: C:\path\to\AD_suiteXXX
├─ User validates path → POST /api/settings/suite-info
│  └─ Backend scans directory structure
│     ├─ Walks all category folders
│     ├─ Discovers check folders (ACC-001, KRB-002, etc.)
│     └─ Returns: {valid: true, checks: 764, categories: 27}
└─ User saves: POST /api/settings {key: 'suiteRoot', value: path}
   └─ Stored in SQLite settings table
```

**2.2 Scan Configuration (Run Scans Page)**
```
User selects scan parameters:
├─ Category selection (Access_Control, Kerberos_Security, etc.)
├─ Check selection (individual checks or "Select All")
├─ Engine selection:
│  ├─ ADSI (no AD module required)
│  ├─ PowerShell (requires ActiveDirectory module)
│  ├─ C# (compiled .NET executables)
│  ├─ CMD (batch scripts)
│  └─ Combined (multi-engine fallback)
├─ Target configuration (optional):
│  ├─ Domain name (FQDN)
│  └─ Server IP (specific DC)
└─ Click "Start Scan"
```

---

### **Phase 3: Scan Execution**

**3.1 Scan Initialization**
```
POST /api/scan/run
├─ Generate scan ID (UUID)
├─ Create scan record in database:
│  └─ INSERT INTO scans (id, timestamp, engine, suite_root, 
│                         domain, server_ip, check_ids, status)
├─ Start SSE connection for real-time updates
└─ Spawn async scan process
```

**3.2 Script Resolution & Execution Loop**
```
For each selected check (e.g., ACC-001):

1. Resolve Script Path
   ├─ Walk category folders (Access_Control/)
   ├─ Find check folder (ACC-001_Privileged_Users_adminCount1/)
   ├─ Locate engine file (adsi.ps1, powershell.ps1, etc.)
   └─ Return: {scriptPath, category}

2. Domain/IP Injection (if specified)
   ├─ Read script content
   ├─ Replace LDAP connection string:
   │  FROM: $root = [ADSI]'LDAP://RootDSE'
   │  TO:   $root = [ADSI]'LDAP://192.168.1.10/DC=domain,DC=local'
   ├─ Write to temp file
   └─ Return temp script path

3. Build Execution Command
   PowerShell:
   ├─ Command: powershell.exe
   ├─ Args: -ExecutionPolicy Bypass -NonInteractive -NoProfile
   │        -Command "& 'script.ps1' | ConvertTo-Json -Depth 10"
   └─ Ensures JSON output for parsing

   CMD:
   └─ Command: cmd.exe /c script.bat

   C#:
   ├─ Compile: csc.exe /reference:System.DirectoryServices.dll script.cs
   └─ Execute: script.exe

4. Spawn Child Process
   ├─ spawn(command, args, {shell: false, timeout: 120000})
   ├─ Capture stdout (script output)
   ├─ Capture stderr (errors)
   └─ Stream logs via SSE to frontend

5. Parse Output
   ├─ Extract JSON from stdout
   ├─ Handle formats:
   │  ├─ JSON array: [{CheckID, Name, Severity, ...}]
   │  ├─ JSON object: {CheckID, Name, Severity, ...}
   │  ├─ NDJSON: Multiple JSON objects per line
   │  └─ Raw text: Wrap in INFO finding
   ├─ Normalize severity (CRITICAL, HIGH, MEDIUM, LOW, INFO)
   └─ Extract BloodHound data structures:
      ├─ ObjectIdentifier (SID)
      ├─ Properties (name, DN, whenCreated)
      ├─ ACEs (permissions)
      ├─ Members (group membership)
      └─ Sessions (logon data)

6. Store Findings
   ├─ For each finding:
   │  └─ INSERT INTO findings (id, scan_id, check_id, check_name,
   │                            category, severity, risk_score, mitre,
   │                            name, distinguished_name, details_json)
   ├─ Save raw output: reports/{scanId}/per_check/{checkId}_raw.json
   └─ Emit progress via SSE: {type: 'progress', current: X, total: Y}

7. Cleanup
   ├─ Delete temp script file
   ├─ Close child process
   └─ Move to next check
```

**3.3 Real-Time Updates (Server-Sent Events)**
```
SSE Stream: /api/scan/stream/{scanId}

Events sent to frontend:
├─ {type: 'progress', progress: {current: 5, total: 20, currentCheckId}}
├─ {type: 'log', line: '[ACC-001] Starting — script.ps1'}
├─ {type: 'log', line: 'Found 4 privileged users'}
├─ {type: 'log', line: '[ACC-001] Done — 4 findings (exit 0)'}
└─ {type: 'complete', summary: {total: 45, bySeverity: {...}}}

Frontend updates:
├─ Progress bar (5/20 checks)
├─ Live log output
├─ Findings counter
└─ Severity breakdown
```

---

### **Phase 4: Results Processing**

**4.1 Scan Finalization**
```
After all checks complete:

1. Calculate Summary
   ├─ Total findings: 45
   ├─ Duration: 127 seconds
   └─ By severity: {CRITICAL: 5, HIGH: 12, MEDIUM: 18, LOW: 8, INFO: 2}

2. Update Database
   └─ UPDATE scans SET finding_count=45, duration_ms=127000, status='completed'

3. Generate Export Files
   ├─ JSON: reports/{scanId}/findings.json
   │  └─ Full findings array with all metadata
   ├─ CSV: reports/{scanId}/findings.csv
   │  └─ Spreadsheet-compatible format
   └─ PDF: reports/{scanId}/report.pdf
      ├─ Cover page with summary
      ├─ Findings grouped by category
      └─ Severity color coding

4. Send Completion Event
   └─ SSE: {type: 'done'}
```

**4.2 Frontend Display**
```
Findings Table Rendering:
├─ Fetch: GET /api/scan/{scanId}/findings?limit=1000
├─ Display columns:
│  ├─ Severity badge (color-coded)
│  ├─ Check name
│  ├─ Object name
│  ├─ Distinguished Name
│  ├─ Category
│  └─ MITRE ATT&CK technique
├─ Filters:
│  ├─ Severity (CRITICAL, HIGH, etc.)
│  ├─ Category (Access_Control, Kerberos, etc.)
│  └─ Search (text match)
└─ Export buttons:
   ├─ JSON → Download findings.json
   ├─ CSV → Download findings.csv
   └─ PDF → Download report.pdf
```

---

### **Phase 5: Advanced Features**

**5.1 Attack Path Visualization**
```
User clicks "Attack Path" tab:

1. Load Graph Data
   ├─ GET /api/reports/graph-data/{scanId}
   ├─ Backend transforms findings into graph:
   │  ├─ Nodes: Users, Groups, Computers, Domains, Findings
   │  ├─ Edges: MemberOf, HasPermission, CanDelegate, etc.
   │  └─ Properties: severity, checkId, MITRE technique
   └─ Returns: {nodes: [...], edges: [...]}

2. Render with Cytoscape.js
   ├─ Node styling by type:
   │  ├─ User: blue circle
   │  ├─ Group: green hexagon
   │  ├─ Computer: gray square
   │  └─ Finding: red diamond (sized by severity)
   ├─ Edge styling by relationship type
   └─ Interactive features:
      ├─ Click node → Show details
      ├─ Hover → Highlight connections
      └─ Layout algorithms (force-directed, hierarchical)

3. LLM Analysis (Optional)
   ├─ User provides API key (Claude, GPT-4, Ollama)
   ├─ POST /api/llm/analyse {findings, provider, apiKey}
   ├─ Backend sends findings to LLM with prompt:
   │  "Analyze these AD findings and identify attack chains"
   ├─ LLM returns:
   │  ├─ Narrative (Markdown explanation)
   │  └─ Graph data (attack path visualization)
   └─ Display in Attack Path page
```

**5.2 BloodHound Integration**
```
User navigates to Integrations → BloodHound:

1. Export to BloodHound Format
   ├─ GET /api/integrations/bloodhound/export/{scanId}
   ├─ Backend transforms findings:
   │  ├─ Extract ObjectIdentifier (SIDs)
   │  ├─ Build BloodHound JSON structure:
   │  │  ├─ users: [{objectid, properties, aces, sessions}]
   │  │  ├─ groups: [{objectid, properties, members}]
   │  │  ├─ computers: [{objectid, properties, sessions}]
   │  │  └─ domains: [{objectid, properties, trusts}]
   │  └─ Validate against BloodHound schema
   └─ Returns: bloodhound_export.json

2. Import to BloodHound
   ├─ User downloads JSON file
   ├─ Opens BloodHound application
   ├─ Drag & drop JSON file
   └─ BloodHound ingests data into Neo4j database

3. Query Attack Paths
   ├─ BloodHound Cypher queries:
   │  ├─ "Shortest path to Domain Admin"
   │  ├─ "Users with DCSync rights"
   │  └─ "Kerberoastable accounts"
   └─ Visualize attack chains
```

**5.3 ADExplorer Snapshot Import**
```
User uploads ADExplorer snapshot:

1. Upload
   ├─ POST /api/integrations/adexplorer/upload (multipart/form-data)
   ├─ Save to: uploads/adexplorer/{filename}.dat
   └─ Return: {snapshotId, filename, size}

2. Parse Snapshot
   ├─ POST /api/integrations/adexplorer/parse/{snapshotId}
   ├─ Spawn PowerShell script: Parse-ADExplorerSnapshot.ps1
   ├─ Extract AD objects:
   │  ├─ Users (samAccountName, DN, UAC flags)
   │  ├─ Groups (members, nesting)
   │  ├─ Computers (OS, lastLogon)
   │  └─ OUs (structure)
   └─ Return: {users: 1234, groups: 567, computers: 890}

3. Run Checks Against Snapshot
   ├─ Use parsed data instead of live LDAP queries
   ├─ Offline analysis (no domain access required)
   └─ Generate findings from snapshot data
```

**5.4 Scheduled Scans**
```
User creates schedule:

1. Configure Schedule
   ├─ Name: "Daily Privileged User Scan"
   ├─ Checks: [ACC-001, ACC-002, PRV-015]
   ├─ Engine: PowerShell
   ├─ Cron: "0 2 * * *" (2 AM daily)
   ├─ Auto-export: BloodHound JSON
   └─ Auto-push: SIEM integration

2. Store Schedule
   └─ INSERT INTO schedules (id, name, check_ids, engine, cron, ...)

3. Cron Execution
   ├─ node-cron monitors schedules
   ├─ At scheduled time:
   │  ├─ Trigger scan: POST /api/scan/run
   │  ├─ Wait for completion
   │  ├─ Export results (if auto-export enabled)
   │  └─ Push to integrations (if auto-push enabled)
   └─ Update: last_run, next_run timestamps
```

**5.6 PowerShell Terminal (Remote Execution)**
```
User opens terminal drawer:

1. WebSocket Connection
   ├─ Frontend: ws://localhost:3000/terminal
   ├─ Backend: Attach WebSocket server to HTTP server
   └─ Establish bidirectional communication

2. Spawn PowerShell Process
   ├─ spawn('powershell.exe', ['-NoExit', '-NoLogo'])
   ├─ Pipe stdin/stdout/stderr to WebSocket
   └─ Maintain persistent session

3. Command Execution
   ├─ User types: Get-ADUser -Filter *
   ├─ Frontend sends via WebSocket
   ├─ Backend writes to PowerShell stdin
   ├─ PowerShell executes command
   ├─ Output captured from stdout
   └─ Streamed back to frontend via WebSocket

4. Terminal Features
   ├─ ANSI color support
   ├─ Command history (up/down arrows)
   ├─ Tab completion
   └─ Multi-line commands
```

---

## **Data Flow Summary**

### **Scan Execution Data Flow**
```
User Input → Frontend State → API Request → Backend Validation
    ↓
Database (scan record) → Script Resolution → Child Process Spawn
    ↓
PowerShell/ADSI Execution → LDAP Queries → Active Directory
    ↓
JSON Output → Parsing → Finding Extraction → Database Storage
    ↓
SSE Stream → Frontend Updates → Real-time Display
    ↓
Export Generation (JSON/CSV/PDF) → File System Storage
    ↓
BloodHound Export → Neo4j Import → Attack Path Analysis
```

### **Key Integration Points**

1. **Frontend ↔ Backend**: REST API + Server-Sent Events
2. **Backend ↔ Scripts**: Child process spawn + stdout/stderr capture
3. **Scripts ↔ Active Directory**: LDAP/ADSI queries
4. **Backend ↔ Database**: SQLite for persistence
5. **Backend ↔ File System**: Report generation & storage
6. **Application ↔ BloodHound**: JSON export/import
7. **Application ↔ Terminal**: WebSocket for remote PowerShell

---

## **Technology Stack**

### **Frontend**
- **React 18** - UI framework
- **Vite** - Build tool & dev server
- **Zustand** - State management
- **TailwindCSS** - Styling
- **Cytoscape.js** - Graph visualization
- **Xterm.js** - Terminal emulator

### **Backend**
- **Node.js 20** - Runtime
- **Express** - Web framework
- **better-sqlite3** - Database
- **child_process** - Script execution
- **Server-Sent Events** - Real-time updates
- **WebSocket** - Terminal communication

### **Scripts**
- **PowerShell 5.1/7** - Primary execution engine
- **ADSI** - Lightweight AD queries
- **C#** - Compiled executables
- **CMD** - Batch scripts

### **Integrations**
- **BloodHound** - Attack path analysis
- **ADExplorer** - Snapshot import
- **LLM APIs** - Claude, GPT-4, Ollama
- **Neo4j** - Graph database (via BloodHound)

---

## **Security Considerations**

1. **Execution Policy**: Scripts run with `-ExecutionPolicy Bypass`
2. **Input Validation**: All user inputs sanitized before execution
3. **Path Traversal**: Script paths validated against suite root
4. **Credential Handling**: No credentials stored in database
5. **CORS**: Restricted to localhost in production
6. **Helmet**: Security headers enabled
7. **SQL Injection**: Parameterized queries only
8. **File Upload**: Size limits & type validation

---

## **Performance Optimizations**

1. **Parallel Execution**: Multiple checks can run concurrently (future)
2. **Streaming**: SSE for real-time updates without polling
3. **Pagination**: Findings loaded in batches (1000 per page)
4. **Indexing**: Database indexes on scan_id, severity, category
5. **Caching**: Category list cached in memory
6. **Lazy Loading**: Frontend components loaded on demand

---

## **Error Handling**

1. **Script Errors**: Captured in stderr, logged, and stored
2. **Parse Errors**: Raw output saved for debugging
3. **Timeout**: 120-second limit per check
4. **Process Crashes**: Graceful cleanup and error reporting
5. **Database Errors**: Transaction rollback and retry
6. **Network Errors**: Retry logic for API calls

---

## **Conclusion**

The AD Security Suite web application provides a comprehensive, user-friendly interface for Active Directory security assessment. It seamlessly integrates:

- **2,258 security checks** across 27 categories
- **Real-time scan execution** with live progress updates
- **Multiple execution engines** (PowerShell, ADSI, C#, CMD)
- **BloodHound integration** for attack path analysis
- **Flexible export formats** (JSON, CSV, PDF)
- **Advanced visualizations** (graphs, charts, attack paths)
- **Remote PowerShell terminal** for ad-hoc queries
- **Scheduled scanning** with automation

All working together to provide enterprise-grade AD security monitoring and compliance reporting.

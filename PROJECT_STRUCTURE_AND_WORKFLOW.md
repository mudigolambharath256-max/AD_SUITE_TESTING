# AD SECURITY SUITE - COMPLETE PROJECT STRUCTURE & WORKFLOW

**Version:** 1.0.0  
**Date:** March 18, 2026  
**Status:** Production Ready  
**Total Categories:** 18  
**Total Checks:** 833  

---

## TABLE OF CONTENTS

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Directory Structure](#directory-structure)
4. [Technology Stack](#technology-stack)
5. [Workflow & Data Flow](#workflow--data-flow)
6. [Component Details](#component-details)
7. [API Endpoints](#api-endpoints)
8. [Database Schema](#database-schema)
9. [Security Check Structure](#security-check-structure)
10. [Execution Engines](#execution-engines)
11. [Integration Points](#integration-points)
12. [Deployment](#deployment)

---

## PROJECT OVERVIEW

### Purpose
Enterprise-grade Active Directory security auditing platform that identifies vulnerabilities, misconfigurations, and security risks across AD environments.

### Key Features
- 833 security checks across 18 categories
- 5 execution engines (ADSI, PowerShell, C#, CMD, Combined)
- Real-time scan monitoring with SSE streaming
- Interactive PowerShell terminal with WebSocket
- Multi-format exports (JSON, CSV, PDF)
- Scheduled scanning with cron
- BloodHound & Neo4j integration
- Attack path visualization
- Modern React-based dashboard


---

## ARCHITECTURE

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER BROWSER                             │
│                    http://localhost:5173                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ HTTP/WebSocket/SSE
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                      FRONTEND (React/Vite)                       │
│  ┌──────────────┬──────────────┬──────────────┬──────────────┐  │
│  │  Dashboard   │  Run Scans   │   Reports    │   Settings   │  │
│  └──────────────┴──────────────┴──────────────┴──────────────┘  │
│  ┌──────────────┬──────────────┬──────────────┬──────────────┐  │
│  │ Integrations │ Attack Path  │   Terminal   │  Schedules   │  │
│  └──────────────┴──────────────┴──────────────┴──────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ REST API (Port 3000)
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                    BACKEND (Node.js/Express)                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    API ROUTES                             │   │
│  │  /api/scan  /api/reports  /api/settings  /api/schedule   │   │
│  └──────────────────────────┬───────────────────────────────┘   │
│  ┌──────────────────────────▼───────────────────────────────┐   │
│  │                    SERVICES LAYER                         │   │
│  │  • executor.js    • db.js         • exporter.js          │   │
│  │  • bloodhound.js  • terminalServer.js                    │   │
│  └──────────────────────────┬───────────────────────────────┘   │
└─────────────────────────────┼─────────────────────────────────┬─┘
                              │                                 │
                              │                                 │
                    ┌─────────▼─────────┐          ┌───────────▼──────────┐
                    │  SQLite Database  │          │  PowerShell Engine   │
                    │   (ad-suite.db)   │          │  (Scan Execution)    │
                    └───────────────────┘          └──────────┬───────────┘
                                                               │
                                                               │
                                                    ┌──────────▼───────────┐
                                                    │  Security Checks     │
                                                    │  (18 Categories)     │
                                                    │  (833 Checks)        │
                                                    └──────────────────────┘
```

### Component Interaction Flow

```
User Action → Frontend Component → API Call → Backend Route → 
Service Layer → Database/PowerShell → Response → Frontend Update
```


---

## DIRECTORY STRUCTURE

### Root Level Structure

```
AD_suiteXXX/
├── .git/                           # Git repository
├── .vscode/                        # VS Code settings
├── ad-suite-web/                   # Web application (main app)
├── AD_suiteXXX/                    # Deployment documentation
├── node_modules/                   # Dependencies
├── backups_20260313_104704/        # Backup folder
│
├── Access_Control/                 # 45 checks
├── Advanced_Security/              # 10 checks
├── Authentication/                 # 33 checks
├── Azure_AD_Integration/           # 42 checks
├── Backup_Recovery/                # 8 checks
├── Certificate_Services/           # 53 checks
├── Computer_Management/            # 50 checks
├── Computers_Servers/              # 60 checks
├── Domain_Configuration/           # 60 checks
├── Group_Policy/                   # 40 checks
├── Infrastructure/                 # 30 checks
├── Kerberos_Security/              # 50 checks
├── LDAP_Security/                  # 25 checks
├── Miscellaneous/                  # 137 checks
├── Network_Security/               # 30 checks
├── Privileged_Access/              # 50 checks
├── Service_Accounts/               # 40 checks
├── Users_Accounts/                 # 70 checks
│
└── AD_Suite_Complete_Check_List.txt  # Master inventory
```

### Web Application Structure (ad-suite-web/)

```
ad-suite-web/
│
├── backend/                        # Node.js/Express backend
│   ├── routes/                     # API endpoints
│   │   ├── scan.js                 # Scan execution routes
│   │   ├── reports.js              # Report management routes
│   │   ├── settings.js             # Settings routes
│   │   ├── integrations.js         # BloodHound/Neo4j routes
│   │   ├── schedule.js             # Cron scheduling routes
│   │   └── adexplorer.js           # AD Explorer routes
│   │
│   ├── services/                   # Business logic
│   │   ├── executor.js             # Scan execution engine
│   │   ├── db.js                   # Database operations
│   │   ├── bloodhound.js           # BloodHound integration
│   │   ├── exporter.js             # Export (JSON/CSV/PDF)
│   │   └── terminalServer.js       # WebSocket terminal
│   │
│   ├── lib/                        # Utilities
│   │   └── categories.js           # Category definitions
│   │
│   ├── data/                       # Data storage
│   │   └── ad-suite.db             # SQLite database
│   │
│   ├── reports/                    # Generated reports
│   │   ├── scan_20260318_120000/   # Report folders
│   │   └── ...                     # (36+ reports)
│   │
│   ├── scripts/                    # Utility scripts
│   │   └── Parse-ADExplorerSnapshot.ps1
│   │
│   ├── server.js                   # Express app entry
│   ├── package.json                # Dependencies
│   └── package-lock.json
│
├── frontend/                       # React/Vite frontend
│   ├── src/
│   │   ├── pages/                  # Main pages
│   │   │   ├── Dashboard.jsx       # Analytics dashboard
│   │   │   ├── RunScans.jsx        # Scan execution UI
│   │   │   ├── Reports.jsx         # Report viewer
│   │   │   ├── Settings.jsx        # Configuration
│   │   │   ├── Integrations.jsx    # External integrations
│   │   │   ├── AttackPath.jsx      # Attack path viz
│   │   │   └── Schedules.jsx       # Cron schedules
│   │   │
│   │   ├── components/             # Reusable components
│   │   │   ├── Terminal.jsx        # Terminal output
│   │   │   ├── PsTerminalDrawer.jsx # Interactive terminal
│   │   │   ├── CheckSelector.jsx   # Check selection UI
│   │   │   ├── FindingsTable.jsx   # Results table
│   │   │   ├── ScanProgress.jsx    # Progress bar
│   │   │   ├── AdGraphVisualiser.jsx # Graph viz
│   │   │   └── ...                 # (20+ components)
│   │   │
│   │   ├── hooks/                  # Custom React hooks
│   │   │   ├── useScan.js          # Scan state management
│   │   │   ├── useSSE.js           # Server-Sent Events
│   │   │   └── useTerminal.js      # Terminal WebSocket
│   │   │
│   │   ├── store/                  # State management
│   │   │   └── useStore.js         # Zustand store
│   │   │
│   │   ├── lib/                    # Utilities
│   │   │   ├── api.js              # API client
│   │   │   ├── categories.js       # Category helpers
│   │   │   └── colors.js           # Theme colors
│   │   │
│   │   ├── App.jsx                 # Root component
│   │   ├── main.jsx                # Entry point
│   │   └── index.css               # Global styles
│   │
│   ├── public/                     # Static assets
│   ├── dist/                       # Production build
│   ├── vite.config.js              # Vite configuration
│   ├── tailwind.config.js          # TailwindCSS config
│   ├── package.json                # Dependencies
│   └── package-lock.json
│
├── install/                        # Installation scripts
│   ├── Setup-ADSuite.ps1           # Initial setup
│   ├── Start-ADSuite.ps1           # Start servers
│   ├── Stop-ADSuite.ps1            # Stop servers
│   └── Uninstall-ADSuite.ps1       # Uninstall
│
├── docker/                         # Docker support
│   ├── Dockerfile                  # Container image
│   ├── docker-compose.yml          # Production compose
│   └── docker-compose.dev.yml      # Dev compose
│
├── docs/                           # Documentation (30+ files)
│   ├── README.md
│   ├── EXECUTIVE_SUMMARY.md
│   ├── QUICK_START.md
│   ├── TESTING_GUIDE.md
│   └── ...
│
├── .env.example                    # Environment template
├── .gitignore                      # Git ignore rules
├── LICENSE                         # MIT License
├── START.bat                       # Windows start script
├── stop.bat                        # Windows stop script
└── DEV.bat                         # Dev mode script
```


### Security Check Category Structure

```
Category_Name/                      # e.g., Access_Control
│
├── CHECK-001_Description/          # e.g., ACC-001_Privileged_Users
│   ├── adsi.ps1                    # ADSI implementation
│   ├── powershell.ps1              # PowerShell implementation
│   ├── csharp.cs                   # C# implementation
│   ├── cmd.bat                     # CMD implementation
│   └── combined_multiengine.ps1    # Multi-engine orchestrator
│
├── CHECK-002_Description/
│   ├── adsi.ps1
│   ├── powershell.ps1
│   ├── csharp.cs
│   ├── cmd.bat
│   └── combined_multiengine.ps1
│
└── ... (up to 137 checks in Miscellaneous)
```


---

## TECHNOLOGY STACK

### Backend Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| Node.js | 16+ | Runtime environment |
| Express.js | 4.x | Web framework |
| better-sqlite3 | 9.x | SQLite database driver |
| ws | 8.x | WebSocket server |
| node-cron | 3.x | Task scheduling |
| helmet | 7.x | Security middleware |
| cors | 2.x | Cross-origin requests |
| node-pty | 1.x | PowerShell terminal PTY |
| pdfkit | 0.x | PDF generation |

### Frontend Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| React | 18.x | UI framework |
| Vite | 5.x | Build tool & dev server |
| TailwindCSS | 3.x | Styling framework |
| Zustand | 4.x | State management |
| React Router | 6.x | Navigation |
| Recharts | 2.x | Data visualization |
| ReactFlow | 11.x | Graph visualization |
| xterm.js | 5.x | Terminal emulation |
| Lucide React | 0.x | Icon library |

### Execution Engines

| Engine | Technology | Requirements |
|--------|------------|--------------|
| ADSI | .NET DirectorySearcher | Windows (built-in) |
| PowerShell | ActiveDirectory module | RSAT tools |
| C# | .NET Framework/SDK | csc.exe or dotnet |
| CMD | dsquery, net commands | Windows (built-in) |
| Combined | Multi-engine orchestration | PowerShell |

### Integration Technologies

| Integration | Purpose |
|-------------|---------|
| BloodHound CE/Legacy | Attack path analysis |
| Neo4j | Graph database |
| MCP Servers | Custom workflows |
| AD Explorer | Snapshot analysis |


---

## WORKFLOW & DATA FLOW

### 1. Application Startup Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    APPLICATION STARTUP                           │
└─────────────────────────────────────────────────────────────────┘

Step 1: Start Backend Server
├── User runs: npm start (in backend/)
├── server.js initializes
├── Express app created
├── Middleware loaded (helmet, cors, body-parser)
├── Database initialized (ad-suite.db)
├── Routes registered (/api/scan, /api/reports, etc.)
├── WebSocket server started (terminal)
├── Cron schedules loaded
└── Server listening on port 3000

Step 2: Start Frontend Server
├── User runs: npm run dev (in frontend/)
├── Vite dev server starts
├── React app compiled
├── Proxy configured (API → localhost:3000)
└── Server listening on port 5173

Step 3: User Access
├── Browser opens http://localhost:5173
├── React app loads
├── Router initializes
├── Zustand store initialized
└── Dashboard page rendered
```

### 2. Scan Execution Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    SCAN EXECUTION FLOW                           │
└─────────────────────────────────────────────────────────────────┘

FRONTEND (RunScans.jsx)
│
├── Step 1: User Configuration
│   ├── Select categories (e.g., Access_Control, Authentication)
│   ├── Select specific checks (e.g., ACC-001, AUTH-002)
│   ├── Choose execution engine (ADSI/PowerShell/C#/CMD/Combined)
│   ├── Configure target (domain, server IP, or auto-discover)
│   └── Click "Run Scan"
│
├── Step 2: API Request
│   ├── POST /api/scan/execute
│   ├── Body: { checks: [...], engine: "adsi", target: {...} }
│   └── Headers: Content-Type: application/json
│
└── Step 3: SSE Connection
    ├── EventSource connects to /api/scan/stream/:scanId
    └── Listens for progress events

BACKEND (routes/scan.js → services/executor.js)
│
├── Step 4: Request Validation
│   ├── Validate checks exist
│   ├── Validate engine is supported
│   ├── Validate suite root path
│   └── Check for concurrent scans (lock mechanism)
│
├── Step 5: Scan Initialization
│   ├── Generate unique scanId (timestamp-based)
│   ├── Create scan record in database
│   ├── Create report directory (reports/scan_YYYYMMDD_HHMMSS/)
│   └── Initialize SSE stream
│
├── Step 6: Check Execution Loop
│   │
│   ├── For each selected check:
│   │   │
│   │   ├── 6a. Locate Script File
│   │   │   ├── Build path: {suiteRoot}/{category}/{checkId}/{engine}.ps1
│   │   │   └── Verify file exists
│   │   │
│   │   ├── 6b. Prepare PowerShell Command
│   │   │   ├── Set execution policy
│   │   │   ├── Inject target variables ($domain, $targetServer)
│   │   │   └── Build command: powershell.exe -File {scriptPath}
│   │   │
│   │   ├── 6c. Execute Script
│   │   │   ├── Spawn child process
│   │   │   ├── Capture stdout/stderr
│   │   │   ├── Monitor execution time
│   │   │   └── Handle errors/timeouts
│   │   │
│   │   ├── 6d. Parse Output
│   │   │   ├── Extract findings (JSON/CSV/text)
│   │   │   ├── Determine severity (Critical/High/Medium/Low/Info)
│   │   │   ├── Count findings
│   │   │   └── Store raw output
│   │   │
│   │   ├── 6e. Save Results
│   │   │   ├── Insert findings into database
│   │   │   ├── Save output to file (reports/{scanId}/{checkId}.txt)
│   │   │   └── Update scan progress
│   │   │
│   │   └── 6f. Stream Progress
│   │       ├── Calculate percentage (completed/total * 100)
│   │       ├── Send SSE event: { type: 'progress', data: {...} }
│   │       └── Update frontend in real-time
│   │
│   └── Continue to next check
│
├── Step 7: Scan Completion
│   ├── Calculate total findings by severity
│   ├── Update scan status to "completed"
│   ├── Generate summary report
│   ├── Send SSE event: { type: 'complete', data: {...} }
│   └── Release scan lock
│
└── Step 8: Error Handling
    ├── Catch execution errors
    ├── Log to database
    ├── Send SSE event: { type: 'error', data: {...} }
    └── Ensure lock is released

FRONTEND (RunScans.jsx)
│
├── Step 9: Progress Updates
│   ├── Receive SSE events
│   ├── Update progress bar (0-100%)
│   ├── Display current check name
│   ├── Show terminal output (color-coded)
│   └── Update severity breakdown chart
│
└── Step 10: Completion
    ├── Display "Scan Complete" message
    ├── Show findings summary
    ├── Enable export buttons (JSON/CSV/PDF)
    └── Add to scan history
```


### 3. Real-Time Terminal Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                  INTERACTIVE TERMINAL FLOW                       │
└─────────────────────────────────────────────────────────────────┘

FRONTEND (PsTerminalDrawer.jsx)
│
├── Step 1: User Opens Terminal
│   ├── Click "PS Terminal" button
│   ├── Drawer slides open
│   └── xterm.js terminal initialized
│
├── Step 2: WebSocket Connection
│   ├── Connect to ws://localhost:3000/terminal
│   ├── Send session request
│   └── Receive session ID
│
└── Step 3: User Interaction
    ├── Type command (e.g., "whoami")
    ├── Press Enter
    └── Send via WebSocket: { type: 'input', data: 'whoami\r\n' }

BACKEND (services/terminalServer.js)
│
├── Step 4: WebSocket Handler
│   ├── Receive WebSocket connection
│   ├── Create PowerShell PTY session
│   ├── Inject context variables:
│   │   ├── $domain = "contoso.com"
│   │   ├── $domainDN = "DC=contoso,DC=com"
│   │   └── $targetServer = "192.168.1.10"
│   └── Send welcome message
│
├── Step 5: Command Execution
│   ├── Receive input from WebSocket
│   ├── Write to PowerShell PTY stdin
│   ├── PowerShell executes command
│   └── Capture output from PTY stdout
│
└── Step 6: Output Streaming
    ├── Read PTY output (real-time)
    ├── Send via WebSocket: { type: 'output', data: '...' }
    └── Continue streaming until command completes

FRONTEND (PsTerminalDrawer.jsx)
│
├── Step 7: Display Output
│   ├── Receive WebSocket message
│   ├── Write to xterm.js terminal
│   └── Apply ANSI color codes
│
└── Step 8: Session Management
    ├── Keep-alive pings
    ├── Handle disconnections
    └── Cleanup on close
```

### 4. Report Export Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    EXPORT WORKFLOW                               │
└─────────────────────────────────────────────────────────────────┘

FRONTEND (Reports.jsx)
│
├── Step 1: User Selects Export
│   ├── Navigate to Reports page
│   ├── Select scan from history
│   ├── Choose format (JSON/CSV/PDF)
│   └── Click export button
│
└── Step 2: API Request
    ├── GET /api/reports/:scanId/export?format=pdf
    └── Set responseType: 'blob'

BACKEND (routes/reports.js → services/exporter.js)
│
├── Step 3: Data Retrieval
│   ├── Query database for scan results
│   ├── Fetch all findings for scanId
│   ├── Group by category and severity
│   └── Calculate statistics
│
├── Step 4: Format Generation
│   │
│   ├── JSON Export
│   │   ├── Structure data as JSON object
│   │   ├── Include metadata (scan date, duration, etc.)
│   │   └── Return as application/json
│   │
│   ├── CSV Export
│   │   ├── Create CSV headers
│   │   ├── Convert findings to rows
│   │   ├── Escape special characters
│   │   └── Return as text/csv
│   │
│   └── PDF Export
│       ├── Initialize PDFKit document
│       ├── Add header with logo/title
│       ├── Add executive summary
│       ├── Add findings table
│       ├── Add severity charts
│       ├── Apply Claude.ai styling
│       └── Return as application/pdf
│
└── Step 5: File Download
    ├── Set Content-Disposition header
    ├── Set filename: scan_{scanId}.{format}
    └── Stream file to response

FRONTEND (Reports.jsx)
│
└── Step 6: Browser Download
    ├── Receive blob response
    ├── Create object URL
    ├── Trigger browser download
    └── Cleanup object URL
```


### 5. Scheduled Scan Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                  SCHEDULED SCAN FLOW                             │
└─────────────────────────────────────────────────────────────────┘

FRONTEND (Schedules.jsx)
│
├── Step 1: Create Schedule
│   ├── User fills form:
│   │   ├── Name: "Daily Security Audit"
│   │   ├── Cron: "0 2 * * *" (2 AM daily)
│   │   ├── Checks: [ACC-001, AUTH-002, ...]
│   │   ├── Engine: "adsi"
│   │   ├── Auto-export: true
│   │   └── Auto-push: false
│   └── POST /api/schedule/create
│
└── Step 2: Schedule Saved
    ├── Backend stores in database
    └── Cron job registered

BACKEND (routes/schedule.js)
│
├── Step 3: Cron Initialization
│   ├── Load all active schedules from database
│   ├── Parse cron expressions
│   ├── Register with node-cron
│   └── Wait for trigger time
│
├── Step 4: Scheduled Execution
│   ├── Cron triggers at specified time
│   ├── Retrieve schedule configuration
│   ├── Call executor.js with schedule params
│   └── Execute scan (same as manual scan)
│
├── Step 5: Post-Scan Actions
│   │
│   ├── Auto-Export (if enabled)
│   │   ├── Generate JSON/CSV/PDF
│   │   ├── Save to reports directory
│   │   └── Log export path
│   │
│   └── Auto-Push (if enabled)
│       ├── Connect to BloodHound/Neo4j
│       ├── Transform findings to graph format
│       ├── Push to database
│       └── Log push status
│
└── Step 6: Notification
    ├── Update schedule last_run timestamp
    ├── Log execution result
    └── (Optional) Send email/webhook notification
```

### 6. BloodHound Integration Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                BLOODHOUND INTEGRATION FLOW                       │
└─────────────────────────────────────────────────────────────────┘

FRONTEND (Integrations.jsx)
│
├── Step 1: Configure BloodHound
│   ├── Enter BloodHound CE URL (http://localhost:8080)
│   ├── Enter API token
│   ├── Test connection
│   └── Save configuration
│
└── Step 2: Push Findings
    ├── Select scan from history
    ├── Click "Push to BloodHound"
    └── POST /api/integrations/bloodhound/push

BACKEND (services/bloodhound.js)
│
├── Step 3: Data Transformation
│   ├── Retrieve scan findings
│   ├── Map to BloodHound schema:
│   │   ├── Users → User nodes
│   │   ├── Groups → Group nodes
│   │   ├── Computers → Computer nodes
│   │   ├── Permissions → Edge relationships
│   │   └── Vulnerabilities → Properties
│   └── Generate JSON payload
│
├── Step 4: API Communication
│   ├── Authenticate with BloodHound API
│   ├── POST /api/v2/graphs/import
│   ├── Send transformed data
│   └── Handle response
│
└── Step 5: Verification
    ├── Query BloodHound for imported data
    ├── Verify node/edge counts
    └── Return status to frontend

FRONTEND (Integrations.jsx)
│
└── Step 6: Display Result
    ├── Show success message
    ├── Display import statistics
    └── Provide link to BloodHound UI
```


---

## COMPONENT DETAILS

### Backend Components

#### 1. server.js (Entry Point)
```javascript
Purpose: Express application initialization
Responsibilities:
  - Load environment variables
  - Initialize Express app
  - Configure middleware (helmet, cors, body-parser)
  - Register routes
  - Start HTTP server
  - Initialize WebSocket server
  - Load cron schedules
  - Handle graceful shutdown
Port: 3000
```

#### 2. routes/scan.js
```javascript
Endpoints:
  - POST /api/scan/execute        # Start new scan
  - GET /api/scan/stream/:scanId  # SSE progress stream
  - GET /api/scan/status/:scanId  # Get scan status
  - POST /api/scan/cancel/:scanId # Cancel running scan
  - GET /api/scan/history         # List all scans
  - DELETE /api/scan/:scanId      # Delete scan

Dependencies: executor.js, db.js
```

#### 3. routes/reports.js
```javascript
Endpoints:
  - GET /api/reports              # List all reports
  - GET /api/reports/:scanId      # Get specific report
  - GET /api/reports/:scanId/export # Export report
  - DELETE /api/reports/:scanId   # Delete report
  - GET /api/reports/:scanId/findings # Get findings

Dependencies: db.js, exporter.js
```

#### 4. routes/settings.js
```javascript
Endpoints:
  - GET /api/settings             # Get all settings
  - PUT /api/settings             # Update settings
  - POST /api/settings/validate   # Validate suite path
  - GET /api/settings/categories  # Get category list

Dependencies: db.js, categories.js
```

#### 5. routes/integrations.js
```javascript
Endpoints:
  - POST /api/integrations/bloodhound/test    # Test connection
  - POST /api/integrations/bloodhound/push    # Push findings
  - POST /api/integrations/neo4j/test         # Test Neo4j
  - POST /api/integrations/neo4j/push         # Push to Neo4j
  - GET /api/integrations/mcp/servers         # List MCP servers

Dependencies: bloodhound.js, db.js
```

#### 6. routes/schedule.js
```javascript
Endpoints:
  - GET /api/schedule             # List schedules
  - POST /api/schedule/create     # Create schedule
  - PUT /api/schedule/:id         # Update schedule
  - DELETE /api/schedule/:id      # Delete schedule
  - POST /api/schedule/:id/run    # Run immediately

Dependencies: db.js, executor.js, node-cron
```

#### 7. services/executor.js
```javascript
Purpose: Core scan execution engine
Key Functions:
  - executeScan(scanConfig)       # Main execution function
  - locateScript(check, engine)   # Find script file
  - runScript(scriptPath, target) # Execute PowerShell
  - parseOutput(stdout)           # Parse findings
  - calculateSeverity(finding)    # Determine severity
  - streamProgress(scanId, data)  # Send SSE events

Execution Flow:
  1. Validate configuration
  2. Create scan record
  3. Loop through checks
  4. Execute each script
  5. Parse and store results
  6. Stream progress
  7. Complete scan
```

#### 8. services/db.js
```javascript
Purpose: SQLite database operations
Key Functions:
  - initDatabase()                # Create tables
  - createScan(scanData)          # Insert scan record
  - getScan(scanId)               # Retrieve scan
  - updateScan(scanId, data)      # Update scan
  - createFinding(findingData)    # Insert finding
  - getFindings(scanId)           # Get all findings
  - createSchedule(scheduleData)  # Insert schedule
  - getSchedules()                # List schedules

Tables:
  - scans (id, timestamp, status, duration, findings_count)
  - findings (id, scan_id, check_id, severity, description)
  - schedules (id, name, cron, checks, engine, enabled)
  - settings (key, value)
```

#### 9. services/exporter.js
```javascript
Purpose: Export scan results to various formats
Key Functions:
  - exportJSON(scanId)            # Generate JSON
  - exportCSV(scanId)             # Generate CSV
  - exportPDF(scanId)             # Generate PDF

PDF Features:
  - Executive summary
  - Severity breakdown chart
  - Findings table with pagination
  - Color-coded severity indicators
  - Claude.ai color scheme
  - Professional formatting
```

#### 10. services/terminalServer.js
```javascript
Purpose: WebSocket PowerShell terminal
Key Functions:
  - handleConnection(ws)          # New WebSocket client
  - createPTY()                   # Spawn PowerShell PTY
  - injectContext(pty, vars)      # Inject AD variables
  - handleInput(data)             # Process user input
  - streamOutput(data)            # Send output to client
  - cleanup()                     # Close PTY session

Features:
  - Real-time command execution
  - ANSI color support
  - Session management
  - Auto-injected variables ($domain, $targetServer)
  - Keep-alive mechanism
```


### Frontend Components

#### 1. App.jsx (Root Component)
```javascript
Purpose: Application root and routing
Responsibilities:
  - React Router setup
  - Route definitions
  - Layout structure
  - Global error boundary
  - Theme provider

Routes:
  / → Dashboard
  /run-scans → RunScans
  /reports → Reports
  /settings → Settings
  /integrations → Integrations
  /attack-path → AttackPath
  /schedules → Schedules
```

#### 2. pages/Dashboard.jsx
```javascript
Purpose: Analytics and overview dashboard
Features:
  - Total scans count
  - Recent scans list
  - Severity distribution chart (Recharts)
  - Category breakdown
  - Quick actions (Run Scan, View Reports)
  - System status indicators

Data Sources:
  - GET /api/scan/history
  - GET /api/reports
  - Zustand store
```

#### 3. pages/RunScans.jsx
```javascript
Purpose: Scan execution interface
Features:
  - Category selector (collapsible tree)
  - Check selector (checkboxes)
  - Engine selector (radio buttons)
  - Target configuration (domain/IP)
  - Run button
  - Progress bar (0-100%)
  - Real-time terminal output
  - Severity breakdown chart
  - Findings table
  - Export buttons (JSON/CSV/PDF)
  - Interactive PowerShell terminal drawer

Components Used:
  - CheckSelector
  - Terminal
  - PsTerminalDrawer
  - ScanProgress
  - FindingsTable

Hooks:
  - useScan (scan state)
  - useSSE (progress streaming)
  - useTerminal (WebSocket)
```

#### 4. pages/Reports.jsx
```javascript
Purpose: Report viewing and management
Features:
  - Scan history table
  - Search and filter
  - Sort by date/status/findings
  - View report details
  - Export options
  - Delete reports
  - Bulk operations

Data Sources:
  - GET /api/reports
  - GET /api/reports/:scanId
```

#### 5. pages/Settings.jsx
```javascript
Purpose: Application configuration
Settings:
  - Suite Root Path (validation)
  - Default Engine
  - Default Target
  - Auto-export preferences
  - Theme settings
  - Database management (export/clear/reset)

API Calls:
  - GET /api/settings
  - PUT /api/settings
  - POST /api/settings/validate
```

#### 6. pages/Integrations.jsx
```javascript
Purpose: External integrations management
Integrations:
  - BloodHound CE
    - URL configuration
    - API token
    - Test connection
    - Push findings
  - BloodHound Legacy
    - File path configuration
    - Import/export
  - Neo4j
    - Connection string
    - Credentials
    - Test connection
  - MCP Servers
    - List servers
    - Configure endpoints

API Calls:
  - POST /api/integrations/bloodhound/test
  - POST /api/integrations/bloodhound/push
  - POST /api/integrations/neo4j/test
```

#### 7. pages/AttackPath.jsx
```javascript
Purpose: Attack path visualization
Features:
  - ReactFlow graph visualization
  - Node types (User, Group, Computer, Domain)
  - Edge types (MemberOf, AdminTo, HasSession)
  - Interactive zoom/pan
  - Node selection
  - Path highlighting
  - Export graph image

Components:
  - AdGraphVisualiser
  - Custom node components
  - Custom edge components
```

#### 8. pages/Schedules.jsx
```javascript
Purpose: Cron schedule management
Features:
  - Schedule list
  - Create schedule form
  - Cron expression builder
  - Check selector
  - Enable/disable toggle
  - Run immediately button
  - Edit/delete schedules
  - Last run timestamp

API Calls:
  - GET /api/schedule
  - POST /api/schedule/create
  - PUT /api/schedule/:id
  - DELETE /api/schedule/:id
```

#### 9. components/CheckSelector.jsx
```javascript
Purpose: Hierarchical check selection UI
Features:
  - Category expansion/collapse
  - Select all/none per category
  - Individual check checkboxes
  - Check count display
  - Search/filter
  - Bulk selection

Props:
  - categories: array
  - selectedChecks: array
  - onSelectionChange: function
```

#### 10. components/Terminal.jsx
```javascript
Purpose: Read-only terminal output display
Features:
  - Color-coded output (ANSI)
  - Auto-scroll
  - Copy to clipboard
  - Clear button
  - Timestamp display
  - Line numbers (optional)

Props:
  - output: string
  - autoScroll: boolean
```

#### 11. components/PsTerminalDrawer.jsx
```javascript
Purpose: Interactive PowerShell terminal
Features:
  - xterm.js terminal emulation
  - WebSocket connection
  - Command input
  - Real-time output
  - ANSI color support
  - Session management
  - Quick command buttons (whoami, ipconfig, etc.)
  - Auto-injected variables display

WebSocket:
  - ws://localhost:3000/terminal
  - Binary/text mode
  - Keep-alive pings
```

#### 12. components/FindingsTable.jsx
```javascript
Purpose: Display scan findings in table format
Features:
  - Sortable columns
  - Filterable by severity
  - Pagination
  - Row selection
  - Export selected
  - Severity color coding
  - Expandable rows (details)

Columns:
  - Check ID
  - Category
  - Severity
  - Description
  - Count
  - Timestamp
```

#### 13. components/ScanProgress.jsx
```javascript
Purpose: Visual scan progress indicator
Features:
  - Progress bar (0-100%)
  - Current check name
  - Completed/total count
  - Estimated time remaining
  - Severity breakdown (live)
  - Cancel button

Props:
  - progress: number (0-100)
  - currentCheck: string
  - completed: number
  - total: number
```

#### 14. components/AdGraphVisualiser.jsx
```javascript
Purpose: ReactFlow graph visualization
Features:
  - Custom node rendering
  - Custom edge rendering
  - Layout algorithms (dagre, force-directed)
  - Zoom controls
  - Minimap
  - Node search
  - Path highlighting
  - Export to PNG/SVG

Node Types:
  - User (blue circle)
  - Group (green square)
  - Computer (red diamond)
  - Domain (purple hexagon)

Edge Types:
  - MemberOf (solid line)
  - AdminTo (dashed line)
  - HasSession (dotted line)
```


---

## API ENDPOINTS

### Complete API Reference

#### Scan Management

```
POST /api/scan/execute
Description: Execute a new security scan
Body: {
  checks: ["ACC-001", "AUTH-002", ...],
  engine: "adsi" | "powershell" | "csharp" | "cmd" | "combined",
  target: {
    domain: "contoso.com",
    serverIp: "192.168.1.10",
    autoDiscover: false
  }
}
Response: {
  scanId: "scan_20260318_120000",
  status: "running",
  message: "Scan started successfully"
}

GET /api/scan/stream/:scanId
Description: Server-Sent Events stream for real-time progress
Response: SSE stream with events:
  - progress: { percent: 45, current: "ACC-001", completed: 9, total: 20 }
  - output: { text: "Checking privileged users...", type: "info" }
  - complete: { findings: 150, duration: 120, status: "completed" }
  - error: { message: "Script execution failed", check: "ACC-001" }

GET /api/scan/status/:scanId
Description: Get current scan status
Response: {
  scanId: "scan_20260318_120000",
  status: "running" | "completed" | "failed" | "cancelled",
  progress: 45,
  startTime: "2026-03-18T12:00:00Z",
  duration: 120,
  findings: 150
}

POST /api/scan/cancel/:scanId
Description: Cancel a running scan
Response: {
  success: true,
  message: "Scan cancelled successfully"
}

GET /api/scan/history
Description: List all scans
Query: ?limit=50&offset=0&status=completed
Response: {
  scans: [
    {
      scanId: "scan_20260318_120000",
      timestamp: "2026-03-18T12:00:00Z",
      status: "completed",
      duration: 120,
      findings: 150,
      categories: ["Access_Control", "Authentication"]
    }
  ],
  total: 100
}

DELETE /api/scan/:scanId
Description: Delete a scan and its findings
Response: {
  success: true,
  message: "Scan deleted successfully"
}
```

#### Report Management

```
GET /api/reports
Description: List all reports
Response: {
  reports: [
    {
      scanId: "scan_20260318_120000",
      timestamp: "2026-03-18T12:00:00Z",
      findings: 150,
      critical: 5,
      high: 20,
      medium: 50,
      low: 75
    }
  ]
}

GET /api/reports/:scanId
Description: Get detailed report
Response: {
  scanId: "scan_20260318_120000",
  timestamp: "2026-03-18T12:00:00Z",
  duration: 120,
  findings: [
    {
      checkId: "ACC-001",
      category: "Access_Control",
      severity: "high",
      description: "5 privileged users found",
      details: {...}
    }
  ],
  summary: {
    total: 150,
    bySeverity: { critical: 5, high: 20, medium: 50, low: 75 },
    byCategory: { Access_Control: 45, Authentication: 33, ... }
  }
}

GET /api/reports/:scanId/export
Description: Export report in specified format
Query: ?format=json|csv|pdf
Response: File download (application/json, text/csv, application/pdf)

DELETE /api/reports/:scanId
Description: Delete a report
Response: {
  success: true,
  message: "Report deleted successfully"
}

GET /api/reports/:scanId/findings
Description: Get findings with pagination
Query: ?page=1&limit=50&severity=high&category=Access_Control
Response: {
  findings: [...],
  total: 150,
  page: 1,
  pages: 3
}
```

#### Settings Management

```
GET /api/settings
Description: Get all settings
Response: {
  suiteRoot: "C:\\AD_Suite",
  defaultEngine: "adsi",
  defaultTarget: {
    domain: "contoso.com",
    serverIp: "192.168.1.10"
  },
  autoExport: true,
  theme: "dark"
}

PUT /api/settings
Description: Update settings
Body: {
  suiteRoot: "C:\\AD_Suite",
  defaultEngine: "adsi",
  ...
}
Response: {
  success: true,
  message: "Settings updated successfully"
}

POST /api/settings/validate
Description: Validate suite root path
Body: {
  path: "C:\\AD_Suite"
}
Response: {
  valid: true,
  categories: 18,
  checks: 833,
  message: "Valid AD Suite installation"
}

GET /api/settings/categories
Description: Get category list with check counts
Response: {
  categories: [
    { id: "Access_Control", display: "Access Control", checkCount: 45 },
    { id: "Authentication", display: "Authentication", checkCount: 33 },
    ...
  ]
}
```

#### Integration Management

```
POST /api/integrations/bloodhound/test
Description: Test BloodHound connection
Body: {
  url: "http://localhost:8080",
  token: "eyJhbGc..."
}
Response: {
  success: true,
  version: "5.0.0",
  message: "Connection successful"
}

POST /api/integrations/bloodhound/push
Description: Push findings to BloodHound
Body: {
  scanId: "scan_20260318_120000"
}
Response: {
  success: true,
  nodes: 150,
  edges: 300,
  message: "Data pushed successfully"
}

POST /api/integrations/neo4j/test
Description: Test Neo4j connection
Body: {
  uri: "bolt://localhost:7687",
  username: "neo4j",
  password: "password"
}
Response: {
  success: true,
  version: "5.0.0",
  message: "Connection successful"
}

POST /api/integrations/neo4j/push
Description: Push findings to Neo4j
Body: {
  scanId: "scan_20260318_120000"
}
Response: {
  success: true,
  nodes: 150,
  relationships: 300,
  message: "Data pushed successfully"
}

GET /api/integrations/mcp/servers
Description: List MCP servers
Response: {
  servers: [
    {
      id: "mcp-server-1",
      name: "Custom Workflow Server",
      status: "running",
      endpoints: [...]
    }
  ]
}
```

#### Schedule Management

```
GET /api/schedule
Description: List all schedules
Response: {
  schedules: [
    {
      id: 1,
      name: "Daily Security Audit",
      cron: "0 2 * * *",
      checks: ["ACC-001", "AUTH-002"],
      engine: "adsi",
      enabled: true,
      lastRun: "2026-03-18T02:00:00Z",
      nextRun: "2026-03-19T02:00:00Z"
    }
  ]
}

POST /api/schedule/create
Description: Create new schedule
Body: {
  name: "Daily Security Audit",
  cron: "0 2 * * *",
  checks: ["ACC-001", "AUTH-002"],
  engine: "adsi",
  autoExport: true,
  autoPush: false
}
Response: {
  success: true,
  scheduleId: 1,
  message: "Schedule created successfully"
}

PUT /api/schedule/:id
Description: Update schedule
Body: {
  name: "Updated Schedule",
  enabled: false,
  ...
}
Response: {
  success: true,
  message: "Schedule updated successfully"
}

DELETE /api/schedule/:id
Description: Delete schedule
Response: {
  success: true,
  message: "Schedule deleted successfully"
}

POST /api/schedule/:id/run
Description: Run schedule immediately
Response: {
  success: true,
  scanId: "scan_20260318_120000",
  message: "Schedule executed successfully"
}
```


---

## DATABASE SCHEMA

### SQLite Database (ad-suite.db)

#### Table: scans
```sql
CREATE TABLE scans (
  id TEXT PRIMARY KEY,              -- scan_20260318_120000
  timestamp TEXT NOT NULL,          -- ISO 8601 format
  status TEXT NOT NULL,             -- running, completed, failed, cancelled
  duration INTEGER,                 -- seconds
  findings_count INTEGER DEFAULT 0,
  critical_count INTEGER DEFAULT 0,
  high_count INTEGER DEFAULT 0,
  medium_count INTEGER DEFAULT 0,
  low_count INTEGER DEFAULT 0,
  info_count INTEGER DEFAULT 0,
  engine TEXT NOT NULL,             -- adsi, powershell, csharp, cmd, combined
  target_domain TEXT,
  target_server TEXT,
  categories TEXT,                  -- JSON array
  checks TEXT,                      -- JSON array
  error_message TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_scans_timestamp ON scans(timestamp);
CREATE INDEX idx_scans_status ON scans(status);
```

#### Table: findings
```sql
CREATE TABLE findings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scan_id TEXT NOT NULL,            -- Foreign key to scans.id
  check_id TEXT NOT NULL,           -- ACC-001, AUTH-002, etc.
  category TEXT NOT NULL,           -- Access_Control, Authentication, etc.
  severity TEXT NOT NULL,           -- critical, high, medium, low, info
  title TEXT NOT NULL,
  description TEXT,
  details TEXT,                     -- JSON object
  raw_output TEXT,                  -- Full script output
  count INTEGER DEFAULT 1,          -- Number of findings
  timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE
);

CREATE INDEX idx_findings_scan_id ON findings(scan_id);
CREATE INDEX idx_findings_severity ON findings(severity);
CREATE INDEX idx_findings_category ON findings(category);
```

#### Table: schedules
```sql
CREATE TABLE schedules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  description TEXT,
  cron TEXT NOT NULL,               -- Cron expression
  checks TEXT NOT NULL,             -- JSON array
  engine TEXT NOT NULL,
  target_domain TEXT,
  target_server TEXT,
  auto_export BOOLEAN DEFAULT 0,
  auto_push BOOLEAN DEFAULT 0,
  enabled BOOLEAN DEFAULT 1,
  last_run TEXT,                    -- ISO 8601 format
  next_run TEXT,                    -- ISO 8601 format
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_schedules_enabled ON schedules(enabled);
CREATE INDEX idx_schedules_next_run ON schedules(next_run);
```

#### Table: settings
```sql
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  type TEXT DEFAULT 'string',       -- string, number, boolean, json
  description TEXT,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Default settings
INSERT INTO settings (key, value, type) VALUES
  ('suiteRoot', '', 'string'),
  ('defaultEngine', 'adsi', 'string'),
  ('defaultDomain', '', 'string'),
  ('defaultServer', '', 'string'),
  ('autoExport', 'false', 'boolean'),
  ('theme', 'dark', 'string'),
  ('bloodhoundUrl', '', 'string'),
  ('bloodhoundToken', '', 'string'),
  ('neo4jUri', '', 'string'),
  ('neo4jUsername', '', 'string'),
  ('neo4jPassword', '', 'string');
```

#### Table: integration_logs
```sql
CREATE TABLE integration_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scan_id TEXT NOT NULL,
  integration TEXT NOT NULL,        -- bloodhound, neo4j, mcp
  action TEXT NOT NULL,             -- push, pull, sync
  status TEXT NOT NULL,             -- success, failed
  nodes_count INTEGER,
  edges_count INTEGER,
  error_message TEXT,
  timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (scan_id) REFERENCES scans(id) ON DELETE CASCADE
);

CREATE INDEX idx_integration_logs_scan_id ON integration_logs(scan_id);
CREATE INDEX idx_integration_logs_integration ON integration_logs(integration);
```


---

## SECURITY CHECK STRUCTURE

### Check Folder Organization

Each security check follows a standardized structure:

```
Category_Name/CHECK-XXX_Description/
├── adsi.ps1                    # ADSI implementation
├── powershell.ps1              # PowerShell implementation
├── csharp.cs                   # C# implementation
├── cmd.bat                     # CMD implementation
└── combined_multiengine.ps1    # Multi-engine orchestrator
```

### Check Implementation Standards

#### 1. ADSI Implementation (adsi.ps1)
```powershell
# Purpose: Pure .NET DirectorySearcher implementation
# Requirements: None (uses built-in .NET classes)
# Performance: Fastest execution

# Standard structure:
param(
    [string]$Domain = $env:USERDNSDOMAIN,
    [string]$Server = $null
)

# Create DirectorySearcher
$searcher = New-Object System.DirectoryServices.DirectorySearcher
$searcher.SearchRoot = "LDAP://$Domain"
$searcher.Filter = "(objectClass=user)"
$searcher.PropertiesToLoad.AddRange(@("sAMAccountName", "distinguishedName"))

# Execute search
$results = $searcher.FindAll()

# Process results
foreach ($result in $results) {
    $user = $result.Properties
    # Output findings in structured format
    [PSCustomObject]@{
        Type = "Finding"
        Severity = "High"
        CheckId = "ACC-001"
        Description = "Privileged user found"
        Details = @{
            SamAccountName = $user.samaccountname[0]
            DistinguishedName = $user.distinguishedname[0]
        }
    } | ConvertTo-Json -Compress
}

# Cleanup
$searcher.Dispose()
```

#### 2. PowerShell Implementation (powershell.ps1)
```powershell
# Purpose: ActiveDirectory module implementation
# Requirements: RSAT ActiveDirectory module
# Performance: Moderate (requires module import)

# Standard structure:
param(
    [string]$Domain = $env:USERDNSDOMAIN,
    [string]$Server = $null
)

# Import module
Import-Module ActiveDirectory -ErrorAction Stop

# Build parameters
$params = @{
    Filter = "adminCount -eq 1"
    Properties = "sAMAccountName", "distinguishedName", "adminCount"
}
if ($Server) { $params.Server = $Server }

# Execute query
$users = Get-ADUser @params

# Process results
foreach ($user in $users) {
    [PSCustomObject]@{
        Type = "Finding"
        Severity = "High"
        CheckId = "ACC-001"
        Description = "Privileged user with adminCount=1"
        Details = @{
            SamAccountName = $user.SamAccountName
            DistinguishedName = $user.DistinguishedName
            AdminCount = $user.adminCount
        }
    } | ConvertTo-Json -Compress
}
```

#### 3. C# Implementation (csharp.cs)
```csharp
// Purpose: Compiled .NET implementation
// Requirements: csc.exe or dotnet SDK
// Performance: Fast (compiled code)

using System;
using System.DirectoryServices;
using System.Text.Json;

class Check {
    static void Main(string[] args) {
        string domain = Environment.GetEnvironmentVariable("USERDNSDOMAIN");
        string server = args.Length > 0 ? args[0] : null;
        
        // Create DirectorySearcher
        DirectoryEntry entry = new DirectoryEntry($"LDAP://{domain}");
        DirectorySearcher searcher = new DirectorySearcher(entry);
        searcher.Filter = "(adminCount=1)";
        searcher.PropertiesToLoad.Add("sAMAccountName");
        searcher.PropertiesToLoad.Add("distinguishedName");
        
        // Execute search
        SearchResultCollection results = searcher.FindAll();
        
        // Process results
        foreach (SearchResult result in results) {
            var finding = new {
                Type = "Finding",
                Severity = "High",
                CheckId = "ACC-001",
                Description = "Privileged user with adminCount=1",
                Details = new {
                    SamAccountName = result.Properties["sAMAccountName"][0],
                    DistinguishedName = result.Properties["distinguishedName"][0]
                }
            };
            Console.WriteLine(JsonSerializer.Serialize(finding));
        }
        
        // Cleanup
        searcher.Dispose();
        entry.Dispose();
    }
}
```

#### 4. CMD Implementation (cmd.bat)
```batch
@echo off
REM Purpose: Legacy CMD implementation
REM Requirements: dsquery, net commands (built-in)
REM Performance: Slowest (text parsing)

setlocal enabledelayedexpansion

REM Get domain
if "%1"=="" (
    set DOMAIN=%USERDNSDOMAIN%
) else (
    set DOMAIN=%1
)

REM Execute dsquery
for /f "tokens=*" %%a in ('dsquery user -limit 0') do (
    REM Get user details
    for /f "tokens=2 delims==" %%b in ("%%a") do (
        echo {"Type":"Finding","Severity":"High","CheckId":"ACC-001","Description":"User found","Details":{"DN":"%%a","CN":"%%b"}}
    )
)

endlocal
```

#### 5. Combined Multi-Engine (combined_multiengine.ps1)
```powershell
# Purpose: Auto-select best available engine
# Requirements: None (graceful fallback)
# Performance: Varies by selected engine

param(
    [string]$Domain = $env:USERDNSDOMAIN,
    [string]$Server = $null
)

# Engine selection logic
$engine = $null

# Try ADSI (always available)
try {
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $engine = "ADSI"
    Write-Host "Using ADSI engine" -ForegroundColor Green
} catch {
    Write-Host "ADSI not available" -ForegroundColor Yellow
}

# Try PowerShell module
if (-not $engine) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        $engine = "PowerShell"
        Write-Host "Using PowerShell engine" -ForegroundColor Green
    } catch {
        Write-Host "ActiveDirectory module not available" -ForegroundColor Yellow
    }
}

# Try C# compilation
if (-not $engine) {
    $cscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    if (Test-Path $cscPath) {
        $engine = "CSharp"
        Write-Host "Using C# engine" -ForegroundColor Green
    }
}

# Fallback to CMD
if (-not $engine) {
    $engine = "CMD"
    Write-Host "Using CMD engine (fallback)" -ForegroundColor Yellow
}

# Execute selected engine
switch ($engine) {
    "ADSI" {
        & "$PSScriptRoot\adsi.ps1" -Domain $Domain -Server $Server
    }
    "PowerShell" {
        & "$PSScriptRoot\powershell.ps1" -Domain $Domain -Server $Server
    }
    "CSharp" {
        # Compile and execute C#
        & $cscPath /out:"$env:TEMP\check.exe" "$PSScriptRoot\csharp.cs"
        & "$env:TEMP\check.exe" $Server
    }
    "CMD" {
        & "$PSScriptRoot\cmd.bat" $Domain
    }
}
```

### Output Format Standards

All checks must output findings in JSON format:

```json
{
  "Type": "Finding",
  "Severity": "Critical" | "High" | "Medium" | "Low" | "Info",
  "CheckId": "ACC-001",
  "Category": "Access_Control",
  "Title": "Short title",
  "Description": "Detailed description",
  "Details": {
    "key1": "value1",
    "key2": "value2"
  },
  "Remediation": "How to fix this issue",
  "References": ["URL1", "URL2"]
}
```


---

## EXECUTION ENGINES

### Engine Comparison

| Feature | ADSI | PowerShell | C# | CMD | Combined |
|---------|------|------------|----|----|----------|
| Speed | ⚡⚡⚡ Fast | ⚡⚡ Moderate | ⚡⚡⚡ Fast | ⚡ Slow | Varies |
| Requirements | None | RSAT | .NET SDK | None | None |
| Reliability | ⭐⭐⭐ High | ⭐⭐⭐ High | ⭐⭐ Medium | ⭐ Low | ⭐⭐⭐ High |
| Flexibility | ⭐⭐ Medium | ⭐⭐⭐ High | ⭐⭐ Medium | ⭐ Low | ⭐⭐⭐ High |
| Best For | Production | Development | Performance | Legacy | Auto-select |

### Engine Selection Logic

```
User selects engine → Backend validates → Locates script file → Executes

Combined Engine Logic:
1. Try ADSI (fastest, no dependencies)
2. If ADSI fails, try PowerShell (most features)
3. If PowerShell fails, try C# (compiled performance)
4. If C# fails, fallback to CMD (always available)
```

### Execution Process

```
┌─────────────────────────────────────────────────────────────────┐
│                    SCRIPT EXECUTION FLOW                         │
└─────────────────────────────────────────────────────────────────┘

Step 1: Locate Script
├── Build path: {suiteRoot}/{category}/{checkId}/{engine}.ps1
├── Verify file exists
└── Read file permissions

Step 2: Prepare Environment
├── Set PowerShell execution policy (Bypass)
├── Inject target variables:
│   ├── $domain = "contoso.com"
│   ├── $domainDN = "DC=contoso,DC=com"
│   └── $targetServer = "192.168.1.10"
└── Set working directory

Step 3: Build Command
├── PowerShell: powershell.exe -ExecutionPolicy Bypass -File {script}
├── C#: csc.exe /out:{temp}.exe {script} && {temp}.exe
└── CMD: cmd.exe /c {script}

Step 4: Spawn Process
├── Create child process
├── Set stdin/stdout/stderr pipes
├── Set timeout (default: 300 seconds)
└── Start process

Step 5: Monitor Execution
├── Read stdout line-by-line
├── Read stderr for errors
├── Check for timeout
├── Track execution time
└── Stream output to frontend (SSE)

Step 6: Parse Output
├── Detect JSON format
├── Parse findings
├── Extract severity
├── Count findings
└── Store in database

Step 7: Cleanup
├── Kill process if timeout
├── Close pipes
├── Delete temp files
└── Release resources
```

### Error Handling

```
Error Types:
1. Script Not Found
   - Check suite root path
   - Verify category/check exists
   - Suggest validation

2. Execution Timeout
   - Default: 300 seconds
   - Configurable per check
   - Kill process gracefully

3. Permission Denied
   - Check execution policy
   - Verify file permissions
   - Suggest running as admin

4. Module Not Found (PowerShell)
   - Detect missing RSAT
   - Suggest installation
   - Fallback to ADSI

5. Compilation Error (C#)
   - Check .NET SDK installed
   - Verify csc.exe path
   - Show compilation errors

6. Parse Error
   - Invalid JSON output
   - Log raw output
   - Continue to next check
```


---

## INTEGRATION POINTS

### 1. BloodHound CE Integration

```
Purpose: Push AD findings to BloodHound for attack path analysis

Data Transformation:
  AD Findings → BloodHound Schema
  
  Users → User Nodes
    - objectSid → objectid
    - sAMAccountName → name
    - enabled → enabled
    - adminCount → admincount
    
  Groups → Group Nodes
    - objectSid → objectid
    - sAMAccountName → name
    - members → MemberOf edges
    
  Computers → Computer Nodes
    - objectSid → objectid
    - dNSHostName → name
    - operatingSystem → operatingsystem
    
  Permissions → Edges
    - GenericAll → GenericAll edge
    - WriteDacl → WriteDacl edge
    - WriteOwner → WriteOwner edge

API Endpoints:
  POST /api/v2/graphs/import
  GET /api/v2/graphs
  POST /api/v2/queries

Authentication:
  Bearer token in Authorization header
```

### 2. BloodHound Legacy Integration

```
Purpose: Import/export BloodHound JSON files

File Format:
  {
    "data": [
      {
        "Properties": {...},
        "AllowedToDelegate": [...],
        "PrimaryGroupSid": "...",
        "Sessions": [...],
        "LocalAdmins": [...]
      }
    ],
    "meta": {
      "count": 100,
      "type": "users"
    }
  }

Import Process:
  1. Read JSON file
  2. Parse data array
  3. Transform to internal format
  4. Store in database
  5. Generate report

Export Process:
  1. Query database
  2. Transform to BloodHound format
  3. Generate JSON file
  4. Save to disk
```

### 3. Neo4j Integration

```
Purpose: Direct graph database integration

Connection:
  URI: bolt://localhost:7687
  Auth: Basic (username/password)
  Driver: neo4j-driver (Node.js)

Cypher Queries:
  // Create User node
  CREATE (u:User {
    objectid: $objectid,
    name: $name,
    enabled: $enabled,
    admincount: $admincount
  })
  
  // Create MemberOf relationship
  MATCH (u:User {objectid: $userId})
  MATCH (g:Group {objectid: $groupId})
  CREATE (u)-[:MemberOf]->(g)
  
  // Find attack paths
  MATCH p=shortestPath(
    (u:User {name: $username})-[*1..]->(g:Group {name: "Domain Admins"})
  )
  RETURN p

Data Push:
  1. Connect to Neo4j
  2. Begin transaction
  3. Create nodes (batch)
  4. Create relationships (batch)
  5. Commit transaction
  6. Verify counts
```

### 4. MCP Server Integration

```
Purpose: Custom workflow automation via Model Context Protocol

MCP Server Types:
  - Custom check execution
  - Data transformation
  - External API integration
  - Notification services

Communication:
  Protocol: HTTP/JSON-RPC
  Methods:
    - execute_check(checkId, params)
    - transform_data(data, format)
    - send_notification(message, channel)

Example Workflow:
  1. Scan completes
  2. Trigger MCP server
  3. MCP transforms findings
  4. MCP sends to external system
  5. MCP returns status
```

### 5. AD Explorer Integration

```
Purpose: Import AD snapshots for offline analysis

Snapshot Format:
  Binary format (.dat file)
  Contains full AD database dump

Import Process:
  1. Parse snapshot file (Parse-ADExplorerSnapshot.ps1)
  2. Extract objects (users, groups, computers)
  3. Extract attributes
  4. Transform to JSON
  5. Import to database
  6. Run checks against snapshot data

Benefits:
  - Offline analysis
  - Historical comparison
  - No live AD access required
  - Forensic investigation
```


---

## DEPLOYMENT

### Development Deployment

```bash
# Prerequisites
- Node.js 16+
- PowerShell 5.1+
- Git

# Step 1: Clone Repository
git clone https://github.com/user/ad-suite.git
cd ad-suite

# Step 2: Install Backend Dependencies
cd ad-suite-web/backend
npm install

# Step 3: Install Frontend Dependencies
cd ../frontend
npm install

# Step 4: Configure Environment
cd ..
cp .env.example .env
# Edit .env with your settings

# Step 5: Initialize Database
cd backend
node -e "require('./services/db').initDatabase()"

# Step 6: Start Backend (Terminal 1)
npm start
# Server running on http://localhost:3000

# Step 7: Start Frontend (Terminal 2)
cd ../frontend
npm run dev
# Server running on http://localhost:5173

# Step 8: Access Application
# Open browser: http://localhost:5173
```

### Production Deployment (Windows)

```powershell
# Step 1: Install as Windows Service
cd ad-suite-web/install
.\Setup-ADSuite.ps1

# Step 2: Configure Service
# Edit: C:\Program Files\AD Suite\config.json

# Step 3: Start Service
.\Start-ADSuite.ps1

# Step 4: Verify
# Backend: http://localhost:3000/api/health
# Frontend: http://localhost:5173

# Step 5: Configure Firewall
New-NetFirewallRule -DisplayName "AD Suite Backend" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "AD Suite Frontend" -Direction Inbound -LocalPort 5173 -Protocol TCP -Action Allow

# Step 6: Configure Auto-Start
Set-Service -Name "ADSuiteBackend" -StartupType Automatic
Set-Service -Name "ADSuiteFrontend" -StartupType Automatic
```

### Docker Deployment

```bash
# Step 1: Build Images
cd ad-suite-web
docker-compose build

# Step 2: Start Containers
docker-compose up -d

# Step 3: Verify
docker-compose ps
docker-compose logs -f

# Step 4: Access Application
# Frontend: http://localhost:5173
# Backend: http://localhost:3000

# Step 5: Stop Containers
docker-compose down

# Step 6: Update
docker-compose pull
docker-compose up -d
```

### Docker Compose Configuration

```yaml
version: '3.8'

services:
  backend:
    build:
      context: ./backend
      dockerfile: ../docker/Dockerfile
    ports:
      - "3000:3000"
    volumes:
      - ./backend/data:/app/data
      - ./backend/reports:/app/reports
      - C:/AD_Suite:/ad-suite:ro
    environment:
      - NODE_ENV=production
      - SUITE_ROOT=/ad-suite
    restart: unless-stopped

  frontend:
    build:
      context: ./frontend
      dockerfile: ../docker/Dockerfile
    ports:
      - "5173:5173"
    depends_on:
      - backend
    environment:
      - VITE_API_URL=http://backend:3000
    restart: unless-stopped

volumes:
  data:
  reports:
```

### Nginx Reverse Proxy (Production)

```nginx
server {
    listen 80;
    server_name ad-suite.company.com;

    # Frontend
    location / {
        proxy_pass http://localhost:5173;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # WebSocket Terminal
    location /terminal {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
    }

    # SSE Stream
    location /api/scan/stream {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Connection '';
        proxy_buffering off;
        proxy_cache off;
        chunked_transfer_encoding off;
    }
}
```

### Environment Variables

```bash
# Backend (.env)
NODE_ENV=production
PORT=3000
SUITE_ROOT=C:\AD_Suite
DB_PATH=./data/ad-suite.db
REPORTS_PATH=./reports
LOG_LEVEL=info
TERMINAL_TIMEOUT=3600000
SCAN_TIMEOUT=300000

# Frontend (.env)
VITE_API_URL=http://localhost:3000
VITE_WS_URL=ws://localhost:3000
VITE_APP_TITLE=AD Security Suite
VITE_APP_VERSION=1.0.0
```

### Monitoring & Logging

```javascript
// Backend Logging (Winston)
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
    new winston.transports.Console()
  ]
});

// Health Check Endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    database: db.isHealthy(),
    terminal: terminalServer.isHealthy()
  });
});
```

### Backup & Recovery

```powershell
# Backup Script
$backupPath = "C:\Backups\AD_Suite"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = "$backupPath\backup_$timestamp"

# Create backup directory
New-Item -ItemType Directory -Path $backupDir

# Backup database
Copy-Item "C:\AD_Suite_Web\backend\data\ad-suite.db" "$backupDir\ad-suite.db"

# Backup reports
Copy-Item -Recurse "C:\AD_Suite_Web\backend\reports" "$backupDir\reports"

# Backup configuration
Copy-Item "C:\AD_Suite_Web\backend\.env" "$backupDir\.env"

# Compress
Compress-Archive -Path $backupDir -DestinationPath "$backupDir.zip"
Remove-Item -Recurse $backupDir

Write-Host "Backup completed: $backupDir.zip"
```

### Security Hardening

```javascript
// Backend Security (Helmet)
const helmet = require('helmet');

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// Rate Limiting
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use('/api/', limiter);

// Authentication (if needed)
const jwt = require('jsonwebtoken');

const authMiddleware = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    res.status(401).json({ error: 'Invalid token' });
  }
};
```


---

## COMPLETE WORKFLOW SUMMARY

### User Journey: From Installation to Report

```
┌─────────────────────────────────────────────────────────────────┐
│                    COMPLETE USER WORKFLOW                        │
└─────────────────────────────────────────────────────────────────┘

Phase 1: Installation & Setup
├── 1. Download AD Suite (833 checks across 18 categories)
├── 2. Extract to C:\AD_Suite
├── 3. Install Node.js 16+
├── 4. Navigate to ad-suite-web/backend
├── 5. Run: npm install
├── 6. Navigate to ad-suite-web/frontend
├── 7. Run: npm install
└── 8. Installation complete

Phase 2: Application Startup
├── 9. Open Terminal 1
├── 10. cd ad-suite-web/backend
├── 11. Run: npm start (Backend starts on port 3000)
├── 12. Open Terminal 2
├── 13. cd ad-suite-web/frontend
├── 14. Run: npm run dev (Frontend starts on port 5173)
└── 15. Open browser: http://localhost:5173

Phase 3: Initial Configuration
├── 16. Navigate to Settings page
├── 17. Enter Suite Root Path: C:\AD_Suite
├── 18. Click "Validate Path"
├── 19. System detects: 18 categories, 833 checks
├── 20. Configure default engine: ADSI
├── 21. Configure default target: contoso.com
├── 22. Save settings
└── 23. Configuration complete

Phase 4: First Scan Execution
├── 24. Navigate to Run Scans page
├── 25. Expand Access_Control category
├── 26. Select checks: ACC-001, ACC-002, ACC-003
├── 27. Expand Authentication category
├── 28. Select checks: AUTH-001, AUTH-002
├── 29. Choose engine: ADSI (fastest)
├── 30. Configure target:
│   ├── Domain: contoso.com
│   └── Server: 192.168.1.10
├── 31. Click "Run Scan"
├── 32. Scan starts (scanId: scan_20260318_120000)
└── 33. Watch real-time progress

Phase 5: Real-Time Monitoring
├── 34. Progress bar updates (0% → 100%)
├── 35. Current check displayed: "ACC-001: Privileged Users"
├── 36. Terminal output streams:
│   ├── [INFO] Starting check ACC-001...
│   ├── [SUCCESS] Found 5 privileged users
│   ├── [INFO] Starting check ACC-002...
│   └── [SUCCESS] Found 3 privileged groups
├── 37. Severity breakdown updates:
│   ├── Critical: 2
│   ├── High: 8
│   ├── Medium: 15
│   └── Low: 20
└── 38. Scan completes in 45 seconds

Phase 6: Review Results
├── 39. Findings table displays 45 findings
├── 40. Filter by severity: High
├── 41. Sort by category
├── 42. Expand finding details
├── 43. Review remediation steps
└── 44. Identify critical issues

Phase 7: Export Report
├── 45. Click "Export PDF"
├── 46. PDF generates with:
│   ├── Executive summary
│   ├── Severity breakdown chart
│   ├── Findings table
│   └── Remediation recommendations
├── 47. File downloads: scan_20260318_120000.pdf
└── 48. Share with team

Phase 8: Interactive Terminal (Optional)
├── 49. Click "PS Terminal" button
├── 50. Terminal drawer opens
├── 51. Variables auto-injected:
│   ├── $domain = "contoso.com"
│   ├── $domainDN = "DC=contoso,DC=com"
│   └── $targetServer = "192.168.1.10"
├── 52. Run commands:
│   ├── whoami
│   ├── Get-ADUser -Filter *
│   └── Test-Connection $targetServer
└── 53. Close terminal

Phase 9: Schedule Automation
├── 54. Navigate to Schedules page
├── 55. Click "Create Schedule"
├── 56. Configure:
│   ├── Name: "Daily Security Audit"
│   ├── Cron: "0 2 * * *" (2 AM daily)
│   ├── Checks: All Access_Control + Authentication
│   ├── Engine: ADSI
│   ├── Auto-export: Enabled (PDF)
│   └── Auto-push: Enabled (BloodHound)
├── 57. Save schedule
└── 58. Schedule runs automatically

Phase 10: BloodHound Integration
├── 59. Navigate to Integrations page
├── 60. Configure BloodHound CE:
│   ├── URL: http://localhost:8080
│   └── Token: eyJhbGc...
├── 61. Test connection: Success
├── 62. Select scan: scan_20260318_120000
├── 63. Click "Push to BloodHound"
├── 64. Data transforms:
│   ├── 150 nodes created
│   └── 300 edges created
├── 65. Open BloodHound UI
└── 66. Visualize attack paths

Phase 11: Ongoing Monitoring
├── 67. Dashboard shows:
│   ├── Total scans: 15
│   ├── Last scan: 2 hours ago
│   ├── Critical findings: 5
│   └── Trend: Improving
├── 68. Review scan history
├── 69. Compare results over time
├── 70. Track remediation progress
└── 71. Generate compliance reports
```


---

## CATEGORY DETAILS

### 18 Active Security Categories

#### 1. Access_Control (45 checks)
```
Focus: Privileged access and permissions
Key Checks:
  - ACC-001: Privileged Users (adminCount=1)
  - ACC-002: Privileged Groups (adminCount=1)
  - ACC-003: Privileged Computers (adminCount=1)
  - ACC-004: Users with SIDHistory
  - ACC-031: Shortest Path to Domain Admin
  - ACC-032: Dangerous ACL Permissions
  - ACC-033: Users with DCSync Rights
  - ACC-034: Kerberoastable Accounts
  - ACC-035: AS-REP Roastable Accounts

Risk Level: Critical
Common Findings: Excessive privileges, weak ACLs, attack paths
```

#### 2. Advanced_Security (10 checks)
```
Focus: Advanced attack vectors and vulnerabilities
Key Checks:
  - ADV-001: Print Spooler Service on DCs
  - ADV-002: Zerologon Vulnerability
  - ADV-003: PetitPotam Vulnerability
  - ADV-004: NoPac Vulnerability
  - ADV-005: sAMAccountName Spoofing
  - ADV-009: ADCS Web Enrollment Vulnerabilities

Risk Level: Critical
Common Findings: Unpatched vulnerabilities, service misconfigurations
```

#### 3. Authentication (33 checks)
```
Focus: Authentication mechanisms and password policies
Key Checks:
  - AUTH-001: Accounts Without Kerberos Pre-Auth
  - AUTH-002: Accounts with Reversible Encryption
  - AUTH-003: Accounts with Password Not Required
  - AUTH-004: Accounts with Never Expiring Password
  - AUTH-030: KRBTGT Password Age
  - AUTH-031: Accounts with Never Expiring Passwords
  - AUTH-032: Accounts with Blank Passwords

Risk Level: High
Common Findings: Weak passwords, disabled pre-auth, stale KRBTGT
```

#### 4. Azure_AD_Integration (42 checks)
```
Focus: Hybrid identity and Azure AD sync
Key Checks:
  - AAD-001: Azure AD Connect Accounts (MSOL)
  - AAD-002: Azure AD Connect Accounts (AAD)
  - AAD-003: Seamless SSO Computer Account
  - AAD-004: AAD Connect Accounts with Admin Rights

Risk Level: High
Common Findings: Overprivileged sync accounts, misconfigured SSO
```

#### 5. Backup_Recovery (8 checks)
```
Focus: Backup and disaster recovery
Key Checks:
  - BCK-001: AD Backup Status
  - BCK-002: System State Backup
  - BCK-003: Tombstone Lifetime
  - BCK-004: Recycle Bin Status

Risk Level: Medium
Common Findings: Missing backups, short tombstone lifetime
```

#### 6. Certificate_Services (53 checks)
```
Focus: PKI and certificate security
Key Checks:
  - CERT-001 to CERT-008: ESC vulnerabilities
  - CERT-009: Certificate Template Permissions
  - CERT-010: CA Health Check
  - CERT-011: Certificate Validation

Risk Level: Critical
Common Findings: ESC1-8 vulnerabilities, weak templates
```

#### 7. Computer_Management (50 checks)
```
Focus: Computer account security
Key Checks:
  - CMGMT-001: LAPS Deployment
  - CMGMT-002: BitLocker Status
  - CMGMT-003: Stale Computer Passwords
  - CMGMT-004: Computer Delegation

Risk Level: High
Common Findings: Missing LAPS, stale passwords, weak delegation
```

#### 8. Computers_Servers (60 checks)
```
Focus: Server and workstation security
Key Checks:
  - CMP-001: Unconstrained Delegation
  - CMP-002: Constrained Delegation
  - CMP-003: LAPS Status
  - CMP-004: Unsupported OS Versions
  - CMP-005: Stale Computer Accounts

Risk Level: High
Common Findings: Delegation issues, unsupported OS, stale accounts
```

#### 9. Domain_Configuration (60 checks)
```
Focus: Domain-wide settings and policies
Key Checks:
  - DCONF-001: Functional Levels
  - DCONF-002: Kerberos Encryption Types
  - DCONF-003: Recycle Bin Status
  - DCONF-004: Password Policies
  - DCONF-005: LDAP Signing
  - DCONF-006: SMB Signing

Risk Level: High
Common Findings: Low functional levels, weak encryption, disabled signing
```

#### 10. Group_Policy (40 checks)
```
Focus: Group Policy security
Key Checks:
  - GPO-001: GPO Inventory
  - GPO-002: WMI Filters
  - GPO-003: Password Policies in GPOs
  - GPO-004: Audit Policies
  - GPO-005: SYSVOL Credentials

Risk Level: High
Common Findings: Credentials in SYSVOL, weak policies, orphaned GPOs
```

#### 11. Infrastructure (30 checks)
```
Focus: AD infrastructure components
Key Checks:
  - INFRA-001: Sites and Subnets
  - INFRA-002: Replication Status
  - INFRA-003: DNS Configuration
  - INFRA-004: DHCP Configuration
  - INFRA-005: Time Synchronization

Risk Level: Medium
Common Findings: Replication issues, DNS misconfig, time drift
```

#### 12. Kerberos_Security (50 checks)
```
Focus: Kerberos authentication security
Key Checks:
  - KRB-001: Kerberoastable Accounts
  - KRB-002: AS-REP Roasting
  - KRB-003: Unconstrained Delegation
  - KRB-004: Constrained Delegation
  - KRB-005: DES Encryption
  - KRB-006: Encryption Types

Risk Level: Critical
Common Findings: Kerberoastable SPNs, weak encryption, delegation abuse
```

#### 13. LDAP_Security (25 checks)
```
Focus: LDAP protocol security
Key Checks:
  - LDAP-001: LDAP Signing
  - LDAP-002: Channel Binding
  - LDAP-003: Anonymous Access
  - LDAP-004: LDAP Encryption
  - LDAP-005: Query Policies

Risk Level: High
Common Findings: Unsigned LDAP, anonymous access, weak encryption
```

#### 14. Miscellaneous (137 checks)
```
Focus: General security checks
Key Checks:
  - MISC-637 to MISC-773: Various security checks
  - Custom checks
  - Extensible framework

Risk Level: Varies
Common Findings: Various security issues not covered by other categories
```

#### 15. Network_Security (30 checks)
```
Focus: Network-level security
Key Checks:
  - NET-001: IPsec Configuration
  - NET-002: Firewall Rules
  - NET-003: Network Segmentation
  - NET-004: VLAN Isolation

Risk Level: Medium
Common Findings: Missing IPsec, weak firewall rules, poor segmentation
```

#### 16. Privileged_Access (50 checks)
```
Focus: Privileged account management
Key Checks:
  - PRV-001: Domain Admins Members
  - PRV-002: Enterprise Admins Members
  - PRV-003: Schema Admins Members
  - PRV-004: Protected Users Group
  - PRV-005: Admin Account Security
  - PRV-006: PAW Compliance

Risk Level: Critical
Common Findings: Excessive admin membership, unprotected accounts
```

#### 17. Service_Accounts (40 checks)
```
Focus: Service account security
Key Checks:
  - SVC-001: SPN Inventory
  - SVC-002: Service Account Password Policies
  - SVC-003: Service Account Delegation
  - SVC-004: gMSA Usage
  - SVC-005: Managed Service Accounts

Risk Level: High
Common Findings: Weak passwords, excessive delegation, missing gMSA
```

#### 18. Users_Accounts (70 checks)
```
Focus: User account security
Key Checks:
  - USR-001: AS-REP Roastable Users
  - USR-002: Kerberoastable Users
  - USR-003: Admin Accounts
  - USR-004: User Delegation
  - USR-005: DES Encryption
  - USR-006: Inactive Accounts
  - USR-007: gMSA Accounts

Risk Level: High
Common Findings: Roastable accounts, inactive users, weak encryption
```

---

## QUICK REFERENCE

### Common Commands

```bash
# Start Development
cd ad-suite-web/backend && npm start
cd ad-suite-web/frontend && npm run dev

# Build Production
cd ad-suite-web/frontend && npm run build

# Run Tests
cd ad-suite-web/backend && npm test
cd ad-suite-web/frontend && npm test

# Database Operations
node -e "require('./services/db').initDatabase()"
node -e "require('./services/db').exportDatabase('./backup.db')"

# Docker Operations
docker-compose up -d
docker-compose down
docker-compose logs -f
```

### Important Paths

```
Suite Root: C:\AD_Suite
Database: ad-suite-web/backend/data/ad-suite.db
Reports: ad-suite-web/backend/reports/
Logs: ad-suite-web/backend/logs/
Config: ad-suite-web/.env
```

### Default Ports

```
Backend: 3000
Frontend: 5173
BloodHound: 8080
Neo4j: 7687
```

### Support & Documentation

```
README: ad-suite-web/README.md
Quick Start: ad-suite-web/QUICK_START.md
Testing Guide: ad-suite-web/TESTING_GUIDE.md
Terminal Guide: ad-suite-web/TERMINAL_QUICK_GUIDE.md
Executive Summary: ad-suite-web/EXECUTIVE_SUMMARY.md
```

---

## CONCLUSION

This AD Security Suite is a comprehensive, production-ready platform for Active Directory security auditing with:

- 833 security checks across 18 categories
- 5 execution engines for flexibility
- Modern web interface with real-time monitoring
- Advanced integrations (BloodHound, Neo4j, MCP)
- Professional reporting capabilities
- Automated scheduling
- Interactive PowerShell terminal
- Graph visualization

The architecture is modular, scalable, and well-documented, making it suitable for enterprise deployment and ongoing security monitoring.

---

**Document Version:** 1.0.0  
**Last Updated:** March 18, 2026  
**Maintained By:** AD Suite Development Team

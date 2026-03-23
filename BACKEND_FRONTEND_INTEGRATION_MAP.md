# Complete Backend-Frontend Integration Mapping
## AD Security Suite Web Application

**Generated**: 2024
**Purpose**: Comprehensive documentation of every API endpoint, SSE stream, WebSocket connection, and data flow between backend and frontend

---

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [API Endpoints by Route](#api-endpoints-by-route)
3. [Real-time Communication](#real-time-communication)
4. [Frontend Components Integration](#frontend-components-integration)
5. [State Management](#state-management)
6. [Data Flow Diagrams](#data-flow-diagrams)

---

## Architecture Overview

### Technology Stack
**Backend**:
- Express.js 4.x (REST API server)
- SQLite (better-sqlite3) for data persistence
- Server-Sent Events (SSE) for real-time progress
- WebSocket (ws) for interactive terminal
- Node-cron for scheduled scans

**Frontend**:
- React 18 with Vite 5
- Zustand for state management (3-store architecture)
- EventSource API for SSE consumption
- WebSocket API for terminal communication
- React Router for navigation

### Communication Patterns
1. **REST API**: Standard HTTP requests for CRUD operations
2. **SSE (Server-Sent Events)**: Unidirectional server→client streaming for scan progress
3. **WebSocket**: Bidirectional communication for interactive PowerShell terminal
4. **File Streaming**: Direct file downloads for exports

---

## API Endpoints by Route


### 1. SCAN ROUTES (`/api/scan/*`)
**Backend File**: `ad-suite-web/backend/routes/scan.js`
**Frontend Consumer**: `RunScans.jsx`, `useScan.js`, `api.js`

#### POST `/api/scan/run`
**Purpose**: Start a new security scan
**Request Body**:
```json
{
  "suiteRoot": "C:\\ADSuite\\AD-Suite-scripts-main",
  "checkIds": ["AUTH-001", "ACC-001", ...],
  "engine": "adsi" | "powershell" | "csharp" | "cmd" | "combined",
  "domain": "contoso.com" (optional),
  "serverIp": "192.168.1.10" (optional)
}
```
**Response**:
```json
{
  "scanId": "uuid-v4-string"
}
```
**Frontend Usage**:
- `useScan.js` → `startScan()` function
- `RunScans.jsx` → `handleRunScan()` button click
- Creates scan record in DB, spawns executor, returns scanId immediately

**Error Responses**:
- 400: Missing parameters or no checks selected
- 409: Scan already running (concurrent scan prevention)
- 500: Internal server error

---

#### GET `/api/scan/stream/:scanId` (SSE)
**Purpose**: Real-time scan progress streaming
**Response**: Server-Sent Events stream
**Event Types**:
```javascript
{ type: 'progress', progress: { current: 5, total: 10, currentCheckId: 'AUTH-001', currentCheckName: '...' } }
{ type: 'log', line: 'Running check AUTH-001...' }
{ type: 'finding', finding: { checkId, name, severity, ... } }
{ type: 'complete', summary: { total: 42, duration: '120s', bySeverity: {...} } }
{ type: 'error', message: 'Error message' }
{ type: 'aborted' }
{ type: 'done' }
```
**Frontend Usage**:
- `useScan.js` → `connectSSE()` function
- `useSSE.js` → SSE connection management with retry logic
- Auto-reconnects with exponential backoff (100ms → 5000ms max)
- Replays existing log lines for reconnecting clients

**Connection Lifecycle**:
1. Frontend calls `/api/scan/run` → receives scanId
2. Frontend opens EventSource to `/api/scan/stream/:scanId`
3. Backend registers SSE client in executor
4. Backend broadcasts events as scan progresses
5. On completion/error, backend closes stream
6. Frontend auto-reconnects if connection drops during active scan

---

#### GET `/api/scan/status/:scanId`
**Purpose**: Get current scan status (polling fallback)
**Response**:
```json
{
  "status": "idle" | "running" | "completed" | "error" | "aborted",
  "progress": null,
  "findingCount": 42
}
```
**Frontend Usage**:
- Rarely used (SSE is primary mechanism)
- Fallback for status checks when SSE unavailable

---

#### POST `/api/scan/abort/:scanId`
**Purpose**: Abort a running scan
**Response**:
```json
{
  "aborted": true
}
```
**Frontend Usage**:
- `useScan.js` → `abortScan()` function
- `RunScans.jsx` → "Abort Scan" button
- Kills active PowerShell processes, updates DB status

---

#### GET `/api/scan/recent`
**Purpose**: Get recent scans for history/dropdown
**Query Params**: `?limit=20` (default: 20)
**Response**:
```json
[
  {
    "id": "uuid",
    "timestamp": 1234567890,
    "engine": "adsi",
    "check_count": 10,
    "finding_count": 42,
    "status": "completed",
    "duration_ms": 120000,
    "domain": "contoso.com",
    "server_ip": "192.168.1.10"
  }
]
```
**Frontend Usage**:
- `Dashboard.jsx` → Recent scans table
- `Reports.jsx` → Scan history
- `Integrations.jsx` → Scan selector dropdown
- `AdGraphVisualiser.jsx` → Scan selector

---

#### GET `/api/scan/:scanId/findings`
**Purpose**: Get findings for a specific scan
**Query Params**: `?offset=0&limit=1000`
**Response**:
```json
{
  "findings": [
    {
      "id": 1,
      "scan_id": "uuid",
      "check_id": "AUTH-001",
      "check_name": "Accounts Without Kerberos Pre-Auth",
      "category": "Authentication",
      "severity": "HIGH",
      "risk_score": 8,
      "mitre": "T1558.004",
      "name": "user@contoso.com",
      "distinguished_name": "CN=user,OU=Users,DC=contoso,DC=com",
      "details_json": "{...}",
      "created_at": "2024-01-01T00:00:00.000Z"
    }
  ]
}
```
**Frontend Usage**:
- `FindingsTable.jsx` → Display findings
- `Reports.jsx` → Expanded scan view
- `useScan.js` → Findings state management

---

#### POST `/api/scan/validate-target`
**Purpose**: Test LDAP connectivity to target domain/server
**Request Body**:
```json
{
  "domain": "contoso.com",
  "serverIp": "192.168.1.10"
}
```
**Response**:
```json
{
  "valid": true,
  "domainNC": "DC=contoso,DC=com",
  "message": "Connection successful"
}
```
**Frontend Usage**:
- `RunScans.jsx` → "Test Connection" button
- Spawns PowerShell to test `[ADSI]'LDAP://...'` connection
- 10-second timeout

---

#### POST `/api/scan/discover-checks`
**Purpose**: Discover available checks from suite root
**Request Body**:
```json
{
  "suiteRoot": "C:\\ADSuite\\AD-Suite-scripts-main"
}
```
**Response**:
```json
{
  "valid": true,
  "totalChecks": 775,
  "categoriesFound": 18,
  "checks": [
    {
      "id": "AUTH-001",
      "name": "Accounts Without Kerberos Pre-Auth",
      "category": "Authentication",
      "folder": "AUTH-001_Accounts_Without_Kerberos_Pre-Auth",
      "engines": ["adsi", "powershell", "csharp"]
    }
  ]
}
```
**Frontend Usage**:
- `RunScans.jsx` → Suite root validation
- `CheckSelector.jsx` → Populate available checks
- Scans filesystem for check folders and script files

---

#### GET `/api/scan/diagnose`
**Purpose**: Run single check with full diagnostics
**Query Params**:
```
?suiteRoot=C:\ADSuite\AD-Suite-scripts-main
&category=Authentication
&checkId=AUTH-001
&engine=adsi
&domain=contoso.com
&targetServer=192.168.1.10
```
**Response**:
```json
{
  "checkId": "AUTH-001",
  "checkName": "Accounts Without Kerberos Pre-Auth",
  "category": "Authentication",
  "engine": "adsi",
  "requestedEngine": "adsi",
  "availableEngines": ["adsi", "powershell", "csharp"],
  "scriptFound": true,
  "scriptPath": "C:\\ADSuite\\...\\adsi.ps1",
  "exitCode": 0,
  "durationMs": 1234,
  "stdoutLength": 5678,
  "stdoutRaw": "...",
  "stderrRaw": "...",
  "findingCount": 3,
  "findings": [...],
  "error": null,
  "diagnosis": "SUCCESS: Script executed successfully and returned 3 findings",
  "suiteRoot": "C:\\ADSuite\\AD-Suite-scripts-main",
  "discoverResult": {
    "valid": true,
    "totalChecks": 775,
    "categoriesFound": 18
  }
}
```
**Frontend Usage**:
- `ScanDiagnostics.jsx` → Diagnostic panel
- `RunScans.jsx` → Troubleshooting tool
- Provides detailed execution info for debugging

---


### 2. BLOODHOUND ROUTES (`/api/bloodhound/*`)
**Backend File**: `ad-suite-web/backend/routes/bloodhound.js`
**Frontend Consumer**: `AdGraphVisualiser.jsx`, `Integrations.jsx`

#### GET `/api/bloodhound/scan/:scanId`
**Purpose**: Get BloodHound-formatted graph data for a scan
**Response**:
```json
{
  "nodes": [
    {
      "ObjectIdentifier": "S-1-5-21-...",
      "Properties": {
        "name": "USER@CONTOSO.COM",
        "domain": "CONTOSO.COM",
        "distinguishedname": "CN=user,OU=Users,DC=contoso,DC=com",
        "samaccountname": "user",
        "enabled": true,
        "admincount": false,
        "adSuiteCheckId": "AUTH-001",
        "adSuiteSeverity": "HIGH"
      },
      "Labels": ["User"],
      "Aces": [],
      "IsDeleted": false,
      "IsACLProtected": false
    }
  ],
  "edges": [
    {
      "id": "edge-1",
      "source": "S-1-5-21-...",
      "target": "S-1-5-21-...",
      "label": "MemberOf",
      "type": "membership"
    }
  ],
  "meta": {
    "scanId": "uuid",
    "nodeCount": 100,
    "edgeCount": 50,
    "timestamp": 1234567890,
    "source": "bloodhound_export" | "findings_conversion"
  }
}
```
**Frontend Usage**:
- `AdGraphVisualiser.jsx` → `loadGraph('bloodhound', scanId)`
- Converts findings to BloodHound v4 JSON format
- Generates nodes (Users, Groups, Computers, Domains)
- Generates edges (MemberOf, Attack paths)

**Data Sources**:
1. **BloodHound Export Files**: Reads from `reports/:scanId/bloodhound/*.json`
2. **Findings Conversion**: Converts scan findings to BloodHound format if no export files exist

---

#### GET `/api/bloodhound/findings/:scanId`
**Purpose**: Convert scan findings to BloodHound format
**Response**: Same as `/api/bloodhound/scan/:scanId`
**Frontend Usage**:
- `AdGraphVisualiser.jsx` → `loadGraph('findings', scanId)`
- Alternative data source when BloodHound export not available

---

#### GET `/api/bloodhound/demo`
**Purpose**: Generate demo BloodHound data for testing
**Response**: Sample graph with 5 nodes and 3 edges
**Frontend Usage**:
- `AdGraphVisualiser.jsx` → "Demo Data" button
- Provides sample visualization without running scans

---

### 3. ADEXPLORER ROUTES (`/api/integrations/adexplorer/*`)
**Backend File**: `ad-suite-web/backend/routes/adexplorer.js`
**Frontend Consumer**: `AdExplorerSection.jsx`, `AdGraphVisualiser.jsx`

#### POST `/api/integrations/adexplorer/convert`
**Purpose**: Convert ADExplorer snapshot to BloodHound JSON
**Request Body**:
```json
{
  "snapshotPath": "C:\\snapshots\\domain.dat",
  "convertExePath": "C:\\tools\\convertsnapshot.exe" (optional)
}
```
**Response**:
```json
{
  "sessionId": "uuid-v4-string"
}
```
**Frontend Usage**:
- `AdExplorerSection.jsx` → "Convert Snapshot" button
- Spawns PowerShell script to parse binary .dat file
- Returns sessionId for SSE streaming

**Conversion Tracks**:
1. **Track 1**: Uses `convertsnapshot.exe` (Rust binary) if provided
2. **Track 2**: Pure PowerShell BinaryReader parser (fallback)

---

#### GET `/api/integrations/adexplorer/stream/:sessionId` (SSE)
**Purpose**: Real-time conversion progress streaming
**Response**: Server-Sent Events stream
**Event Types**:
```javascript
{ type: 'log', line: 'Parsing binary snapshot...' }
{ type: 'complete', code: 0, summary: '1234 nodes, 567 edges', outputFiles: ['graph.json', 'users.json'], sessionId: 'uuid', graphAvailable: true }
{ type: 'error', message: 'Error message' }
```
**Frontend Usage**:
- `AdExplorerSection.jsx` → Real-time progress log
- Auto-scrolling terminal output
- Completion notification with file list

---

#### GET `/api/integrations/adexplorer/graph/:sessionId`
**Purpose**: Serve unified graph.json for visualization
**Response**: JSON stream of graph data
```json
{
  "nodes": [...],
  "edges": [...],
  "meta": {
    "domain": "CONTOSO.COM",
    "server": "DC01",
    "snapshotTime": 1234567890,
    "nodeCount": 1234,
    "edgeCount": 567
  }
}
```
**Frontend Usage**:
- `AdGraphVisualiser.jsx` → `loadGraph('adexplorer', sessionId)`
- Direct integration with graph visualizer

---

#### GET `/api/integrations/adexplorer/files/:sessionId`
**Purpose**: List generated JSON files
**Response**:
```json
{
  "files": ["graph.json", "CONTOSO.COM_users.json", "CONTOSO.COM_groups.json"],
  "outputDir": "C:\\uploads\\adexplorer\\uuid"
}
```
**Frontend Usage**:
- `AdExplorerSection.jsx` → Output files panel
- Displays available files with download/push/visualize actions

---

#### GET `/api/integrations/adexplorer/download/:sessionId/:filename`
**Purpose**: Download individual converted file
**Response**: File stream with `Content-Disposition: attachment`
**Frontend Usage**:
- `AdExplorerSection.jsx` → "Download" button per file
- Path traversal protection via `path.basename()`

---

### 4. INTEGRATIONS ROUTES (`/api/integrations/*`)
**Backend File**: `ad-suite-web/backend/routes/integrations.js`
**Frontend Consumer**: `Integrations.jsx`

#### GET `/api/integrations/bloodhound/test`
**Purpose**: Test BloodHound connection
**Query Params**:
```
?url=http://localhost:8080
&username=neo4j
&password=password
&version=CE
```
**Response**:
```json
{
  "connected": true,
  "version": "CE",
  "message": "Connection successful"
}
```
**Frontend Usage**:
- `Integrations.jsx` → "Test Connection" button
- Validates BloodHound CE/Legacy connectivity

---

#### POST `/api/integrations/bloodhound/push`
**Purpose**: Push findings to BloodHound
**Request Body**:
```json
{
  "scanId": "uuid",
  "config": {
    "url": "http://localhost:8080",
    "username": "neo4j",
    "password": "password",
    "version": "CE"
  }
}
```
**Response**:
```json
{
  "pushed": true,
  "count": 42,
  "message": "Successfully pushed 42 findings"
}
```
**Frontend Usage**:
- `Integrations.jsx` → "Push Findings" button

---

#### GET `/api/integrations/neo4j/test`
**Purpose**: Test Neo4j database connection
**Query Params**:
```
?boltUri=bolt://localhost:7687
&username=neo4j
&password=password
&database=neo4j
```
**Response**:
```json
{
  "connected": true
}
```
**Frontend Usage**:
- `Integrations.jsx` → "Test Connection" button

---

#### POST `/api/integrations/neo4j/push`
**Purpose**: Push findings to Neo4j as graph
**Request Body**:
```json
{
  "scanId": "uuid",
  "config": {
    "boltUri": "bolt://localhost:7687",
    "username": "neo4j",
    "password": "password",
    "database": "neo4j"
  }
}
```
**Response**:
```json
{
  "nodesCreated": 100,
  "relationshipsCreated": 50,
  "totalFindings": 42
}
```
**Frontend Usage**:
- `Integrations.jsx` → "Push as Graph" button
- Creates ADFinding, Category, MITRETechnique nodes
- Creates BELONGS_TO, MAPS_TO relationships

---

#### GET `/api/integrations/mcp/test`
**Purpose**: Test MCP server connection
**Query Params**:
```
?serverUrl=https://mcp.example.com
&apiKey=key
&workspaceId=workspace-id
```
**Response**:
```json
{
  "connected": true,
  "serverInfo": {...}
}
```
**Frontend Usage**:
- `Integrations.jsx` → "Test Connection" button

---

#### POST `/api/integrations/mcp/push`
**Purpose**: Push findings to MCP server
**Request Body**:
```json
{
  "scanId": "uuid",
  "config": {
    "serverUrl": "https://mcp.example.com",
    "apiKey": "key",
    "workspaceId": "workspace-id"
  }
}
```
**Response**:
```json
{
  "pushed": true,
  "count": 42,
  "response": {...}
}
```
**Frontend Usage**:
- `Integrations.jsx` → "Push Findings" button

---


### 5. REPORTS ROUTES (`/api/reports/*`)
**Backend File**: `ad-suite-web/backend/routes/reports.js`
**Frontend Consumer**: `Reports.jsx`, `RunScans.jsx`

#### POST `/api/reports/export`
**Purpose**: Export scan results in various formats
**Request Body**:
```json
{
  "scanIds": ["uuid1", "uuid2"],
  "format": "json" | "csv" | "pdf"
}
```
**Response**: File stream with appropriate Content-Type
- JSON: `application/json`
- CSV: `text/csv`
- PDF: `application/pdf`

**Frontend Usage**:
- `Reports.jsx` → Bulk export buttons
- `RunScans.jsx` → Export buttons after scan completion
- Single scan: Reads from `reports/:scanId/findings.{json|csv}` or `report.pdf`
- Multiple scans: Merges findings, generates temporary file, streams, then deletes

---

#### POST `/api/reports/delete`
**Purpose**: Delete scan reports and findings
**Request Body**:
```json
{
  "scanIds": ["uuid1", "uuid2"]
}
```
**Response**:
```json
{
  "deleted": true,
  "scansDeleted": 2,
  "findingsDeleted": 84
}
```
**Frontend Usage**:
- `Reports.jsx` → "Delete Selected" button
- Deletes from database and filesystem

---

#### GET `/api/reports/graph-data/:scanId`
**Purpose**: Convert scan findings to Cytoscape graph format
**Response**:
```json
{
  "nodes": [
    {
      "id": "finding-1",
      "label": "user@contoso.com",
      "type": "User",
      "properties": {
        "severity": "HIGH",
        "checkId": "AUTH-001",
        "checkName": "...",
        "category": "Authentication",
        "mitre": "T1558.004"
      }
    }
  ],
  "edges": [
    {
      "source": "finding-1",
      "target": "cat_Authentication",
      "type": "BelongsTo",
      "label": "BelongsTo"
    }
  ],
  "meta": {
    "scanId": "uuid",
    "nodeCount": 100,
    "edgeCount": 50
  }
}
```
**Frontend Usage**:
- `AdGraphVisualiser.jsx` → Legacy graph format support
- Maps findings to nodes based on category

---

### 6. SCHEDULE ROUTES (`/api/schedules/*`)
**Backend File**: `ad-suite-web/backend/routes/schedule.js`
**Frontend Consumer**: `Settings.jsx` (future), `Dashboard.jsx` (future)

#### GET `/api/schedules`
**Purpose**: Get all scheduled scans
**Response**:
```json
[
  {
    "id": "uuid",
    "name": "Daily Full Scan",
    "checkIds": ["AUTH-001", "ACC-001"],
    "engine": "adsi",
    "cron": "0 2 * * *",
    "autoExport": "json",
    "autoPush": "bloodhound",
    "enabled": 1,
    "lastRun": 1234567890,
    "nextRun": 1234567890,
    "createdAt": 1234567890
  }
]
```
**Frontend Usage**: Not yet implemented in UI

---

#### POST `/api/schedules`
**Purpose**: Create new scheduled scan
**Request Body**:
```json
{
  "name": "Daily Full Scan",
  "checkIds": ["AUTH-001", "ACC-001"],
  "engine": "adsi",
  "cronExpression": "0 2 * * *",
  "autoExport": "json",
  "autoPush": "bloodhound"
}
```
**Response**: Created schedule object
**Frontend Usage**: Not yet implemented in UI

---

#### PUT `/api/schedules/:id`
**Purpose**: Update scheduled scan
**Request Body**: Partial schedule object
**Response**: Updated schedule object
**Frontend Usage**: Not yet implemented in UI

---

#### DELETE `/api/schedules/:id`
**Purpose**: Delete scheduled scan
**Response**:
```json
{
  "deleted": true
}
```
**Frontend Usage**: Not yet implemented in UI

---

#### POST `/api/schedules/:id/run`
**Purpose**: Manually trigger scheduled scan
**Response**:
```json
{
  "scanId": "uuid",
  "message": "Scan started"
}
```
**Frontend Usage**: Not yet implemented in UI

---

### 7. SETTINGS ROUTES (`/api/settings/*`)
**Backend File**: `ad-suite-web/backend/routes/settings.js`
**Frontend Consumer**: `Settings.jsx`, `RunScans.jsx`

#### GET `/api/settings/suite-info`
**Purpose**: Scan suite root directory for checks
**Query Params**: `?path=C:\ADSuite\AD-Suite-scripts-main`
**Response**:
```json
{
  "valid": true,
  "categories": 18,
  "checks": 775,
  "engines": {
    "adsi": 775,
    "powershell": 775,
    "csharp": 650,
    "cmd": 400,
    "combined": 775
  },
  "categoryList": [
    {
      "name": "Authentication",
      "checkCount": 33
    }
  ]
}
```
**Frontend Usage**:
- `Settings.jsx` → Suite root validation
- Scans filesystem for category folders and check scripts

---

#### POST `/api/settings/detect-csc`
**Purpose**: Auto-detect C# compiler location
**Response**:
```json
{
  "found": true,
  "path": "C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe"
}
```
**Frontend Usage**:
- `Settings.jsx` → "Auto-detect csc.exe" button
- Checks known paths and uses `where.exe`

---

#### POST `/api/settings/test-execution-policy`
**Purpose**: Test PowerShell execution
**Response**:
```json
{
  "ok": true,
  "message": "PowerShell is working correctly"
}
```
**Frontend Usage**:
- `Settings.jsx` → "Test PowerShell" button
- Runs simple PowerShell command with Bypass policy

---

#### POST `/api/settings/export-db`
**Purpose**: Export SQLite database
**Response**: File stream (application/octet-stream)
**Frontend Usage**:
- `Settings.jsx` → "Export DB as JSON" button
- Downloads `ad-suite-{timestamp}.db`

---

#### POST `/api/settings/clear-history`
**Purpose**: Clear all scan history
**Response**:
```json
{
  "success": true,
  "message": "Scan history cleared"
}
```
**Frontend Usage**:
- `Settings.jsx` → "Clear history" button
- Deletes all scans and findings from DB

---

#### POST `/api/settings/reset-db`
**Purpose**: Reset database to initial state
**Response**:
```json
{
  "success": true,
  "message": "Database reset successfully"
}
```
**Frontend Usage**:
- `Settings.jsx` → "Reset all data (danger)" button
- Drops and recreates all tables

---

#### POST `/api/settings/save`
**Purpose**: Save a setting key-value pair
**Request Body**:
```json
{
  "key": "suiteRoot",
  "value": "C:\\ADSuite\\AD-Suite-scripts-main"
}
```
**Response**:
```json
{
  "saved": true
}
```
**Frontend Usage**:
- `Settings.jsx` → All setting inputs
- Persists to `settings` table in SQLite

---

#### POST `/api/settings/browse-folder`
**Purpose**: Browse filesystem folders
**Request Body**:
```json
{
  "path": "C:\\ADSuite"
}
```
**Response**:
```json
{
  "currentPath": "C:\\ADSuite",
  "parentPath": "C:\\",
  "items": [
    {
      "name": "AD-Suite-scripts-main",
      "path": "C:\\ADSuite\\AD-Suite-scripts-main",
      "isDirectory": true,
      "size": 0,
      "modified": "2024-01-01T00:00:00.000Z"
    }
  ]
}
```
**Frontend Usage**:
- `FolderBrowser.jsx` → Folder navigation modal
- `Settings.jsx` → Browse button for suite root

---

#### GET `/api/settings/:key`
**Purpose**: Get a setting value
**Response**:
```json
{
  "value": "C:\\ADSuite\\AD-Suite-scripts-main"
}
```
**Frontend Usage**:
- `Settings.jsx` → Load saved settings on mount
- 404 if setting not found

---

### 8. DASHBOARD ROUTES (`/api/dashboard/*`)
**Backend File**: `ad-suite-web/backend/server.js`
**Frontend Consumer**: `Dashboard.jsx`

#### GET `/api/dashboard/severity-summary`
**Purpose**: Get severity counts for latest scan
**Response**:
```json
{
  "CRITICAL": 5,
  "HIGH": 12,
  "MEDIUM": 20,
  "LOW": 5,
  "INFO": 0
}
```
**Frontend Usage**:
- `Dashboard.jsx` → Severity pie chart
- Queries latest completed scan from DB

---

#### GET `/api/dashboard/category-summary`
**Purpose**: Get category counts for latest scan
**Response**:
```json
[
  {
    "category": "Authentication",
    "count": 15
  },
  {
    "category": "Access_Control",
    "count": 12
  }
]
```
**Frontend Usage**:
- `Dashboard.jsx` → Category bar chart

---

### 9. SYSTEM ROUTES (`/api/*`)
**Backend File**: `ad-suite-web/backend/server.js`
**Frontend Consumer**: Various components

#### GET `/api/health`
**Purpose**: Health check and system status
**Response**:
```json
{
  "status": "healthy",
  "suiteRoot": "C:\\ADSuite\\AD-Suite-scripts-main",
  "dbSize": 1048576,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```
**Frontend Usage**:
- `Settings.jsx` → Load health data
- Monitoring and diagnostics

---

#### GET `/api/categories`
**Purpose**: Get all available check categories
**Response**:
```json
[
  {
    "id": "Authentication",
    "display": "Authentication",
    "prefix": "AUTH",
    "checkCount": 33
  }
]
```
**Frontend Usage**:
- `CheckSelector.jsx` → Category list
- `Dashboard.jsx` → Category navigation

---

#### POST `/api/llm/analyse`
**Purpose**: Analyze findings with LLM (Anthropic/OpenAI/Ollama)
**Request Body**:
```json
{
  "findings": [...],
  "provider": "anthropic" | "openai" | "ollama",
  "apiKey": "key",
  "model": "claude-3-sonnet-20240229"
}
```
**Response**:
```json
{
  "narrative": "Markdown analysis...",
  "nodes": [...],
  "edges": [...]
}
```
**Frontend Usage**: Not yet implemented in UI
**Purpose**: AI-powered attack chain analysis

---


## Real-time Communication

### 1. Server-Sent Events (SSE)

#### Scan Progress Stream
**Endpoint**: `GET /api/scan/stream/:scanId`
**Backend**: `ad-suite-web/backend/routes/scan.js`
**Frontend**: `ad-suite-web/frontend/src/hooks/useScan.js`, `useSSE.js`

**Connection Flow**:
```
1. Frontend: POST /api/scan/run → scanId
2. Frontend: new EventSource(`/api/scan/stream/${scanId}`)
3. Backend: Register client in executor.sseClients Map
4. Backend: Broadcast events via res.write(`data: ${JSON.stringify(event)}\n\n`)
5. Frontend: eventSource.onmessage → Parse JSON → Update state
6. On completion: Backend closes stream, Frontend closes EventSource
```

**Event Types**:
- `progress`: Scan progress update (current/total checks)
- `log`: Terminal output line
- `finding`: New finding discovered
- `complete`: Scan finished successfully
- `error`: Scan failed
- `aborted`: Scan was aborted
- `done`: Stream closing signal

**Retry Logic**:
- Frontend implements exponential backoff: 100ms → 200ms → 400ms → ... → 5000ms max
- Auto-reconnects on connection drop if scan still running
- Replays existing log lines for reconnecting clients

**State Management**:
```javascript
// Backend (executor.js)
const sseClients = new Map(); // scanId → res

function registerSSEClient(scanId, res) {
  sseClients.set(scanId, res);
}

function broadcastSSE(scanId, event) {
  const client = sseClients.get(scanId);
  if (client && !client.writableEnded) {
    client.write(`data: ${JSON.stringify(event)}\n\n`);
  }
}

// Frontend (useScan.js)
const connectSSE = (scanId) => {
  const es = new EventSource(`/api/scan/stream/${scanId}`);
  
  es.onmessage = (e) => {
    const event = JSON.parse(e.data);
    // Update Zustand store based on event type
  };
  
  es.onerror = () => {
    // Reconnect with backoff
  };
};
```

---

#### ADExplorer Conversion Stream
**Endpoint**: `GET /api/integrations/adexplorer/stream/:sessionId`
**Backend**: `ad-suite-web/backend/routes/adexplorer.js`
**Frontend**: `ad-suite-web/frontend/src/components/AdExplorerSection.jsx`

**Connection Flow**: Same as scan progress stream

**Event Types**:
- `log`: Conversion progress message
- `complete`: Conversion finished (includes summary, outputFiles, graphAvailable)
- `error`: Conversion failed

**Usage**:
```javascript
// Frontend (AdExplorerSection.jsx)
const sse = new EventSource(`/api/integrations/adexplorer/stream/${sessionId}`);

sse.onmessage = (e) => {
  const msg = JSON.parse(e.data);
  
  if (msg.type === 'log') {
    setLogLines(prev => [...prev.slice(-499), msg]); // Ring buffer
  }
  
  if (msg.type === 'complete') {
    setStatus('complete');
    setOutputFiles(msg.outputFiles);
    setGraphAvailable(msg.graphAvailable);
    sse.close();
  }
};
```

---

### 2. WebSocket Communication

#### Interactive PowerShell Terminal
**Endpoint**: `ws://localhost:3001` (upgraded from HTTP)
**Backend**: `ad-suite-web/backend/services/terminalServer.js`
**Frontend**: `ad-suite-web/frontend/src/components/PsTerminalDrawer.jsx`, `useTerminal.js`

**Connection Flow**:
```
1. Frontend: new WebSocket('ws://localhost:3001')
2. Backend: ws.on('connection') → Create ConPTY process
3. Frontend: Send command via ws.send(JSON.stringify({ type: 'input', data: 'command\n' }))
4. Backend: Write to ConPTY stdin
5. Backend: Read from ConPTY stdout → ws.send(JSON.stringify({ type: 'output', data: '...' }))
6. Frontend: Display in xterm.js terminal
7. On close: Backend kills ConPTY process
```

**Message Types**:
```javascript
// Client → Server
{
  type: 'input',
  data: 'Get-ADUser -Filter *\n'
}

{
  type: 'resize',
  cols: 80,
  rows: 24
}

// Server → Client
{
  type: 'output',
  data: 'PS C:\\> Get-ADUser -Filter *\n...'
}

{
  type: 'error',
  message: 'ConPTY process failed'
}

{
  type: 'exit',
  code: 0
}
```

**Backend Implementation**:
```javascript
// terminalServer.js
const { spawn } = require('node-pty');

wss.on('connection', (ws) => {
  const ptyProcess = spawn('powershell.exe', [], {
    name: 'xterm-256color',
    cols: 80,
    rows: 24,
    cwd: process.env.HOME,
    env: process.env
  });

  ptyProcess.onData((data) => {
    ws.send(JSON.stringify({ type: 'output', data }));
  });

  ws.on('message', (msg) => {
    const { type, data, cols, rows } = JSON.parse(msg);
    
    if (type === 'input') {
      ptyProcess.write(data);
    }
    
    if (type === 'resize') {
      ptyProcess.resize(cols, rows);
    }
  });

  ws.on('close', () => {
    ptyProcess.kill();
  });
});
```

**Frontend Implementation**:
```javascript
// useTerminal.js
const connectTerminal = () => {
  const ws = new WebSocket('ws://localhost:3001');
  const term = new Terminal();
  
  ws.onopen = () => {
    term.onData((data) => {
      ws.send(JSON.stringify({ type: 'input', data }));
    });
  };
  
  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data);
    
    if (msg.type === 'output') {
      term.write(msg.data);
    }
  };
  
  term.onResize(({ cols, rows }) => {
    ws.send(JSON.stringify({ type: 'resize', cols, rows }));
  });
};
```

**Features**:
- Full PTY emulation with ConPTY (Windows)
- ANSI color support
- Terminal resizing
- Command history (handled by PowerShell)
- Auto-reconnect on connection loss

---

## Frontend Components Integration

### Component Hierarchy and API Usage

```
App.jsx
├── Dashboard.jsx
│   ├── GET /api/dashboard/severity-summary
│   ├── GET /api/dashboard/category-summary
│   └── GET /api/scan/recent
│
├── RunScans.jsx
│   ├── POST /api/scan/run
│   ├── SSE /api/scan/stream/:scanId
│   ├── POST /api/scan/abort/:scanId
│   ├── POST /api/scan/validate-target
│   ├── POST /api/scan/discover-checks
│   ├── GET /api/scan/diagnose
│   ├── POST /api/reports/export
│   ├── CheckSelector.jsx
│   │   └── Uses store.availableChecks (from discover-checks)
│   ├── EngineSelector.jsx
│   ├── ScanProgress.jsx
│   ├── FindingsTable.jsx
│   ├── Terminal.jsx
│   ├── PsTerminalDrawer.jsx
│   │   └── WebSocket ws://localhost:3001
│   └── ScanDiagnostics.jsx
│       └── GET /api/scan/diagnose
│
├── Reports.jsx
│   ├── GET /api/scan/recent
│   ├── GET /api/scan/:scanId/findings
│   ├── POST /api/reports/export
│   ├── POST /api/reports/delete
│   └── FindingsTable.jsx
│
├── Integrations.jsx
│   ├── GET /api/scan/recent
│   ├── GET /api/integrations/bloodhound/test
│   ├── POST /api/integrations/bloodhound/push
│   ├── GET /api/integrations/neo4j/test
│   ├── POST /api/integrations/neo4j/push
│   ├── GET /api/integrations/mcp/test
│   ├── POST /api/integrations/mcp/push
│   ├── AdExplorerSection.jsx
│   │   ├── POST /api/integrations/adexplorer/convert
│   │   ├── SSE /api/integrations/adexplorer/stream/:sessionId
│   │   ├── GET /api/integrations/adexplorer/files/:sessionId
│   │   └── GET /api/integrations/adexplorer/download/:sessionId/:filename
│   └── AdGraphVisualiser.jsx
│       ├── GET /api/scan/recent
│       ├── GET /api/bloodhound/scan/:scanId
│       ├── GET /api/bloodhound/findings/:scanId
│       ├── GET /api/bloodhound/demo
│       ├── GET /api/integrations/adexplorer/graph/:sessionId
│       └── GET /api/reports/graph-data/:scanId
│
└── Settings.jsx
    ├── GET /api/health
    ├── GET /api/settings/suite-info
    ├── POST /api/settings/detect-csc
    ├── POST /api/settings/test-execution-policy
    ├── POST /api/settings/export-db
    ├── POST /api/settings/clear-history
    ├── POST /api/settings/reset-db
    ├── POST /api/settings/save
    ├── POST /api/settings/browse-folder
    ├── GET /api/settings/:key
    └── FolderBrowser.jsx
        └── POST /api/settings/browse-folder
```

---

### Custom Hooks and API Integration

#### useScan.js
**Purpose**: Manage scan lifecycle and state
**API Calls**:
- `POST /api/scan/run` → Start scan
- `SSE /api/scan/stream/:scanId` → Progress updates
- `POST /api/scan/abort/:scanId` → Abort scan
- `GET /api/scan/recent` → Refresh history after completion

**State Management**:
- Connects to Zustand stores: `useAppStore`, `useFindingsStore`, `useHistoryStore`
- Manages SSE connection with auto-reconnect
- Handles scan status transitions: idle → running → complete/error/aborted

**Usage**:
```javascript
const { 
  scanStatus, 
  progress, 
  findings, 
  logLines, 
  scanSummary, 
  scanError, 
  activeScanId,
  startScan, 
  abortScan, 
  resetScan 
} = useScan();
```

---

#### useSSE.js
**Purpose**: Generic SSE connection management
**Features**:
- Exponential backoff retry (100ms → 5000ms)
- Connection state tracking
- Manual reconnect function
- Automatic cleanup on unmount

**Usage**:
```javascript
const { data, isConnected, error, reconnect, disconnect } = useSSE(scanId);
```

---

#### useTerminal.js
**Purpose**: WebSocket terminal connection management
**API Calls**:
- `WebSocket ws://localhost:3001`

**Features**:
- xterm.js integration
- PTY process management
- Terminal resize handling
- Auto-reconnect on connection loss

**Usage**:
```javascript
const { 
  terminal, 
  isConnected, 
  connect, 
  disconnect, 
  sendCommand 
} = useTerminal();
```

---


## State Management

### Zustand Store Architecture

The application uses a 3-store architecture with different persistence strategies:

#### 1. useAppStore (localStorage)
**File**: `ad-suite-web/frontend/src/store/index.js`
**Persistence**: localStorage (fast, synchronous, small data)
**Purpose**: Configuration, selection, active scan state

**State Slices**:

**Config Slice**:
```javascript
{
  suiteRoot: string,
  domain: string,
  serverIp: string,
  engine: 'adsi' | 'powershell' | 'csharp' | 'cmd' | 'combined',
  suiteRootValid: boolean,
  availableChecks: Array<Check>
}
```

**Selection Slice**:
```javascript
{
  selectedCheckIds: string[],
  expandedCategories: { [categoryId]: boolean }
}
```

**Scan Slice**:
```javascript
{
  activeScanId: string | null,
  scanStatus: 'idle' | 'running' | 'complete' | 'error' | 'aborted',
  progress: {
    current: number,
    total: number,
    currentCheckId: string,
    currentCheckName: string
  },
  scanSummary: {
    duration: string,
    total: number,
    bySeverity: { CRITICAL: number, HIGH: number, ... }
  } | null,
  scanError: string | null
}
```

**Reports Slice**:
```javascript
{
  reportFilters: {
    dateFrom: Date | null,
    dateTo: Date | null,
    severities: string[],
    categories: string[],
    engines: string[],
    search: string
  },
  selectedScanIds: string[]
}
```

**Actions**:
- `setSuiteRoot(v)`, `setDomain(v)`, `setServerIp(v)`, `setEngine(v)`
- `setSuiteRootValid(v)`, `setAvailableChecks(checks)`
- `setSelectedCheckIds(ids)`, `toggleCheck(id)`, `toggleCategory(categoryId, checkIds)`
- `selectAll(allCheckIds)`, `clearAll()`
- `setActiveScan(scanId)`, `setScanStatus(status)`, `updateProgress(progress)`
- `setScanSummary(summary)`, `setScanError(err)`, `resetScan()`
- `setReportFilters(filters)`, `updateReportFilter(key, value)`, `clearReportFilters()`

---

#### 2. useFindingsStore (IndexedDB)
**File**: `ad-suite-web/frontend/src/store/index.js`
**Persistence**: IndexedDB (async, large data)
**Purpose**: Store large findings arrays

**State**:
```javascript
{
  findings: Array<Finding>,
  logLines: Array<{ ts: number, line: string }> // NOT persisted
}
```

**Actions**:
- `setFindings(findings)`
- `addFinding(finding)`
- `appendLog(line)` // Ring buffer (max 1000 lines)
- `clearFindings()`

**Why IndexedDB?**:
- Findings can be 1000+ objects with large JSON details
- localStorage has 5-10MB limit
- IndexedDB supports 50MB+ per origin
- Async operations don't block UI

---

#### 3. useHistoryStore (No Persistence)
**File**: `ad-suite-web/frontend/src/store/index.js`
**Persistence**: None (always fetched fresh from DB)
**Purpose**: Recent scans list

**State**:
```javascript
{
  recentScans: Array<Scan>,
  historyLoading: boolean
}
```

**Actions**:
- `setRecentScans(scans)`
- `setHistoryLoading(v)`

**Why No Persistence?**:
- Scan history changes on backend (new scans, deletions)
- Always fetch fresh data from `/api/scan/recent`
- Avoids stale data issues

---

### State Synchronization Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    USER ACTION                               │
│  (e.g., Click "Run Scan" button)                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  COMPONENT EVENT HANDLER                     │
│  RunScans.jsx → handleRunScan()                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    CUSTOM HOOK                               │
│  useScan.js → startScan()                                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    API CALL                                  │
│  POST /api/scan/run                                         │
│  Body: { checkIds, engine, suiteRoot, domain, serverIp }   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  BACKEND PROCESSING                          │
│  1. Validate parameters                                     │
│  2. Check if scan already running                           │
│  3. Create scan record in DB                                │
│  4. Spawn executor.runScan() asynchronously                 │
│  5. Return scanId immediately                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  FRONTEND STATE UPDATE                       │
│  store.setActiveScan(scanId)                                │
│  → activeScanId = scanId                                    │
│  → scanStatus = 'running'                                   │
│  → progress = { current: 0, total: 0 }                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  SSE CONNECTION                              │
│  new EventSource(`/api/scan/stream/${scanId}`)              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  REAL-TIME UPDATES                           │
│  Backend broadcasts events:                                 │
│  • progress → store.updateProgress()                        │
│  • log → findingsStore.appendLog()                          │
│  • finding → findingsStore.addFinding()                     │
│  • complete → store.setScanSummary()                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  COMPONENT RE-RENDER                         │
│  React detects Zustand state change                         │
│  → RunScans.jsx re-renders with new data                    │
│  → ScanProgress.jsx shows updated progress                  │
│  → FindingsTable.jsx displays new findings                  │
└─────────────────────────────────────────────────────────────┘
```

---

### Persistence Strategy

**localStorage** (useAppStore):
- ✅ Fast synchronous access
- ✅ Survives page refresh
- ✅ Small data (< 1MB)
- ❌ 5-10MB limit
- **Use for**: Config, selections, active scan state

**IndexedDB** (useFindingsStore):
- ✅ Large data support (50MB+)
- ✅ Async operations
- ✅ Survives page refresh
- ❌ Slower than localStorage
- **Use for**: Findings arrays, large datasets

**No Persistence** (useHistoryStore):
- ✅ Always fresh data
- ✅ No stale data issues
- ❌ Requires network fetch
- **Use for**: Dynamic server data (scan history)

---

## Data Flow Diagrams

### 1. Scan Execution Flow

```
┌──────────────┐
│   Frontend   │
│  RunScans.jsx│
└──────┬───────┘
       │ 1. User clicks "Run Scan"
       │
       ▼
┌──────────────┐
│   useScan.js │
│  startScan() │
└──────┬───────┘
       │ 2. POST /api/scan/run
       │    { checkIds, engine, suiteRoot, domain, serverIp }
       ▼
┌──────────────────────────────────────────────────────────┐
│                    Backend: scan.js                       │
│  1. Validate parameters                                  │
│  2. Check executor.isScanning() → 409 if already running │
│  3. db.createScan({ id, timestamp, engine, ... })        │
│  4. setImmediate(() => executor.runScan(...))            │
│  5. res.json({ scanId })                                 │
└──────┬───────────────────────────────────────────────────┘
       │ 3. Return scanId
       ▼
┌──────────────┐
│   useScan.js │
│  connectSSE()│
└──────┬───────┘
       │ 4. new EventSource(`/api/scan/stream/${scanId}`)
       ▼
┌──────────────────────────────────────────────────────────┐
│                Backend: executor.runScan()                │
│  FOR EACH checkId:                                       │
│    1. Build script path                                  │
│    2. Inject domain/IP into script                       │
│    3. spawn('powershell.exe', [script])                  │
│    4. Capture stdout/stderr                              │
│    5. Parse JSON output                                  │
│    6. broadcastSSE({ type: 'progress', ... })            │
│    7. broadcastSSE({ type: 'finding', ... })             │
│    8. db.insertFinding(...)                              │
│    9. Write export files (JSON/CSV/PDF)                  │
│  END FOR                                                 │
│  10. broadcastSSE({ type: 'complete', summary })         │
│  11. db.updateScanStatus('completed')                    │
└──────┬───────────────────────────────────────────────────┘
       │ 5. SSE events stream
       ▼
┌──────────────┐
│   useScan.js │
│  es.onmessage│
└──────┬───────┘
       │ 6. Parse event, update Zustand stores
       ▼
┌──────────────────────────────────────────────────────────┐
│                    Zustand Stores                         │
│  • store.updateProgress({ current, total, ... })         │
│  • findingsStore.appendLog(line)                         │
│  • findingsStore.addFinding(finding)                     │
│  • store.setScanSummary({ duration, total, ... })        │
└──────┬───────────────────────────────────────────────────┘
       │ 7. State change triggers re-render
       ▼
┌──────────────┐
│   Frontend   │
│  Components  │
│  Re-render   │
└──────────────┘
```

---

### 2. ADExplorer Snapshot Conversion Flow

```
┌──────────────────┐
│    Frontend      │
│ AdExplorerSection│
└────────┬─────────┘
         │ 1. User uploads .dat file, clicks "Convert"
         ▼
┌──────────────────┐
│ handleConvert()  │
└────────┬─────────┘
         │ 2. POST /api/integrations/adexplorer/convert
         │    { snapshotPath, convertExePath }
         ▼
┌────────────────────────────────────────────────────────────┐
│              Backend: adexplorer.js                         │
│  1. Validate snapshot file exists                          │
│  2. Create sessionId = uuidv4()                            │
│  3. Create outputDir = uploads/adexplorer/:sessionId       │
│  4. sessions.set(sessionId, { status: 'running', ... })    │
│  5. spawn('powershell.exe', [Parse-ADExplorerSnapshot.ps1])│
│  6. res.json({ sessionId })                                │
└────────┬───────────────────────────────────────────────────┘
         │ 3. Return sessionId
         ▼
┌──────────────────┐
│ AdExplorerSection│
│ Open SSE stream  │
└────────┬─────────┘
         │ 4. new EventSource(`/api/integrations/adexplorer/stream/${sessionId}`)
         ▼
┌────────────────────────────────────────────────────────────┐
│        Backend: Parse-ADExplorerSnapshot.ps1                │
│  TRACK 1 (if convertExePath provided):                     │
│    1. & $ConvertExePath --output bloodhound.tar.gz $path   │
│    2. tar -xzf bloodhound.tar.gz                           │
│    3. Build graph.json from extracted files                │
│                                                            │
│  TRACK 2 (pure PowerShell):                                │
│    1. Open binary file with BinaryReader                   │
│    2. Read header (magic, server, timestamp, counts)       │
│    3. Parse properties table (attribute definitions)       │
│    4. Parse classes table (object class names)             │
│    5. Parse LDAP objects:                                  │
│       • Read attributes with syntax-specific parsing       │
│       • Classify by objectClass (user/group/computer)      │
│       • Extract SIDs, DNs, UAC flags                       │
│    6. Transform to BloodHound JSON v4:                     │
│       • Convert-ToBloodHoundUser                           │
│       • Convert-ToBloodHoundGroup                          │
│       • Convert-ToBloodHoundComputer                       │
│       • Convert-ToBloodHoundDomain                         │
│    7. Write individual JSON files:                         │
│       • DOMAIN_users.json                                  │
│       • DOMAIN_groups.json                                 │
│       • DOMAIN_computers.json                              │
│       • DOMAIN_domains.json                                │
│    8. Build unified graph.json:                            │
│       • Create nodes from all objects                      │
│       • Create MemberOf edges from group members           │
│       • Add metadata (domain, server, counts)              │
│                                                            │
│  Write-Progress-Message → stdout → SSE broadcast           │
│  Write-Output "SUMMARY:..." → stdout → parsed by backend   │
└────────┬───────────────────────────────────────────────────┘
         │ 5. stdout/stderr streams
         ▼
┌────────────────────────────────────────────────────────────┐
│              Backend: adexplorer.js                         │
│  proc.stdout.on('data'):                                   │
│    • Append to session.lines                               │
│    • broadcastSSE({ type: 'log', line })                   │
│                                                            │
│  proc.on('close'):                                         │
│    • Parse SUMMARY line                                    │
│    • List output files                                     │
│    • Update session.status                                 │
│    • broadcastSSE({ type: 'complete', summary, files })    │
└────────┬───────────────────────────────────────────────────┘
         │ 6. SSE events stream
         ▼
┌──────────────────┐
│ AdExplorerSection│
│ sse.onmessage    │
└────────┬─────────┘
         │ 7. Update UI state
         ▼
┌────────────────────────────────────────────────────────────┐
│                    Frontend State                           │
│  • setLogLines([...prev, msg]) → Display in terminal       │
│  • setStatus('complete')                                   │
│  • setOutputFiles(msg.outputFiles) → Show file list        │
│  • setGraphAvailable(true) → Enable "Open in Graph" button │
└────────┬───────────────────────────────────────────────────┘
         │ 8. User clicks "Open in Graph Visualiser"
         ▼
┌──────────────────┐
│ AdGraphVisualiser│
│ loadGraph()      │
└────────┬─────────┘
         │ 9. GET /api/integrations/adexplorer/graph/:sessionId
         ▼
┌────────────────────────────────────────────────────────────┐
│              Backend: adexplorer.js                         │
│  • Read graph.json from session outputDir                  │
│  • Stream file to client                                   │
└────────┬───────────────────────────────────────────────────┘
         │ 10. JSON response
         ▼
┌──────────────────┐
│ AdGraphVisualiser│
│ Cytoscape render │
└──────────────────┘
```

---

### 3. Interactive Terminal Flow

```
┌──────────────────┐
│    Frontend      │
│ PsTerminalDrawer │
└────────┬─────────┘
         │ 1. User clicks "Open Terminal"
         ▼
┌──────────────────┐
│ useTerminal.js   │
│ connect()        │
└────────┬─────────┘
         │ 2. new WebSocket('ws://localhost:3001')
         ▼
┌────────────────────────────────────────────────────────────┐
│           Backend: terminalServer.js                        │
│  wss.on('connection', (ws) => {                            │
│    1. Create ConPTY process:                               │
│       ptyProcess = spawn('powershell.exe', [], {           │
│         name: 'xterm-256color',                            │
│         cols: 80, rows: 24                                 │
│       })                                                   │
│                                                            │
│    2. Forward PTY output to WebSocket:                     │
│       ptyProcess.onData((data) => {                        │
│         ws.send(JSON.stringify({ type: 'output', data }))  │
│       })                                                   │
│                                                            │
│    3. Handle WebSocket messages:                           │
│       ws.on('message', (msg) => {                          │
│         if (type === 'input') ptyProcess.write(data)       │
│         if (type === 'resize') ptyProcess.resize(cols,rows)│
│       })                                                   │
│                                                            │
│    4. Cleanup on close:                                    │
│       ws.on('close', () => ptyProcess.kill())              │
│  })                                                        │
└────────┬───────────────────────────────────────────────────┘
         │ 3. WebSocket connection established
         ▼
┌──────────────────┐
│ useTerminal.js   │
│ ws.onopen        │
└────────┬─────────┘
         │ 4. Initialize xterm.js terminal
         ▼
┌────────────────────────────────────────────────────────────┐
│                    xterm.js Terminal                        │
│  • Render terminal UI                                      │
│  • Capture user input                                      │
│  • Display output with ANSI colors                         │
└────────┬───────────────────────────────────────────────────┘
         │ 5. User types command: "Get-ADUser -Filter *"
         ▼
┌──────────────────┐
│ xterm.js         │
│ term.onData()    │
└────────┬─────────┘
         │ 6. ws.send(JSON.stringify({ type: 'input', data: 'Get-ADUser...\n' }))
         ▼
┌────────────────────────────────────────────────────────────┐
│           Backend: terminalServer.js                        │
│  ws.on('message'):                                         │
│    • Parse JSON message                                    │
│    • ptyProcess.write(data) → Send to PowerShell stdin     │
└────────┬───────────────────────────────────────────────────┘
         │ 7. PowerShell executes command
         ▼
┌────────────────────────────────────────────────────────────┐
│                PowerShell Process                           │
│  • Execute: Get-ADUser -Filter *                           │
│  • Generate output with ANSI colors                        │
│  • Write to stdout                                         │
└────────┬───────────────────────────────────────────────────┘
         │ 8. stdout data
         ▼
┌────────────────────────────────────────────────────────────┐
│           Backend: terminalServer.js                        │
│  ptyProcess.onData((data)):                                │
│    • ws.send(JSON.stringify({ type: 'output', data }))     │
└────────┬───────────────────────────────────────────────────┘
         │ 9. WebSocket message
         ▼
┌──────────────────┐
│ useTerminal.js   │
│ ws.onmessage     │
└────────┬─────────┘
         │ 10. term.write(msg.data)
         ▼
┌──────────────────┐
│ xterm.js         │
│ Display output   │
└──────────────────┘
```

---

## Summary

This document provides a complete mapping of every integration point between the backend and frontend of the AD Security Suite Web Application. Key takeaways:

1. **REST API**: 40+ endpoints across 7 route files
2. **SSE Streams**: 2 real-time progress streams (scan, ADExplorer conversion)
3. **WebSocket**: 1 bidirectional terminal connection
4. **State Management**: 3-store Zustand architecture with strategic persistence
5. **Data Flow**: Clear separation of concerns with hooks abstracting API complexity

All endpoints are documented with request/response formats, frontend consumers, and usage examples.


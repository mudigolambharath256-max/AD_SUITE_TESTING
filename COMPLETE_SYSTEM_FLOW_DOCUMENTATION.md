# AD Suite - Complete System Flow Documentation
## Every Component, Data Flow, Page, Graph, Report & Table Explained

**Generated:** April 2, 2026  
**Document Type:** Comprehensive End-to-End Analysis  
**Total Pages:** 10 Web Pages | 756 Security Checks | 40+ API Endpoints

---

## EXECUTIVE SUMMARY

This document provides an exhaustive analysis of the AD Suite platform, covering:
- **10 Web Pages** with complete user flows
- **Every data transmission** from frontend to backend to PowerShell
- **All graph visualizations** (Sigma.js, D3, Cytoscape, Mermaid, Recharts)
- **Complete report generation** pipeline (PDF, Excel, CSV, JSON)
- **Every table and data structure** in the system
- **Real-time WebSocket** communication flows
- **PowerShell scanning engine** execution details

---

## PART 1: WEB PAGES - COMPLETE BREAKDOWN

### PAGE 1: LOGIN PAGE (`/login`)

**Purpose:** User authentication gateway

**Components:**
- Email input field
- Password input field
- Submit button
- Demo credentials display
- Error message display

**Data Flow:**
```
1. USER ACTION: Enter credentials
   ├─> Frontend: React state (email, password)
   └─> Validation: Required fields check

2. SUBMIT BUTTON CLICK
   ├─> Frontend: handleSubmit()
   ├─> API Call: POST /api/auth/login
   │   └─> Body: { email, password }
   │
   ├─> Backend: authController.login()
   │   ├─> Validate credentials
   │   ├─> Query database/check hardcoded users
   │   ├─> Hash password with bcrypt
   │   ├─> Compare hashes
   │   ├─> Generate JWT token
   │   │   └─> Payload: { userId, email, role }
   │   │   └─> Sign with JWT_SECRET
   │   │   └─> Expiration: 24h
   │   └─> Return: { user, token }
   │
   └─> Frontend: Receive response
       ├─> Store in authStore (Zustand)
       │   ├─> user object
       │   └─> token string
       ├─> Set axios default header
       │   └─> Authorization: Bearer <token>
       ├─> Navigate to /dashboard
       └─> Show success message

3. ERROR HANDLING
   ├─> 401: Invalid credentials
   ├─> 500: Server error
   └─> Network error: Connection failed
```

**State Management:**
```typescript
// authStore (Zustand)
{
  user: {
    id: string
    email: string
    role: 'admin' | 'user'
    createdAt: Date
  },
  token: string,
  isAuthenticated: boolean,
  login: (user, token) => void,
  logout: () => void
}
```

**UI Elements:**
- Logo: `/technieum-logo.png` (h-12, max-w-180px)
- Title: "Technieum AD suite" (text-xl, break-words)
- Subtitle: "Security Assessment Platform" (text-xs)
- Form: Email + Password inputs with focus states
- Button: "Sign In" with loading state
- Demo box: Credentials display with copy functionality

---

### PAGE 2: DASHBOARD PAGE (`/`)

**Purpose:** Real-time security posture overview and command center

**Components:**
1. **Header Section**
   - Title: "Security Command Center"
   - Refresh indicator (spinning icon when refetching)
   - "Run New Scan" button

2. **Metrics Cards (4 cards)**
   - Posture Score Card
   - Findings Delta Card
   - Identity Checks Card
   - Critical Exposure Card

3. **Charts Section**
   - Security Posture Trend (Area Chart)
   - Severity Distribution (Pie Chart)

4. **Quick Actions Panel**
   - Run Full Suite button
   - Kerberos Audit button
   - View All Reports button

5. **Recent Activity Table**
   - Scan ID column
   - Status column
   - Findings count
   - Timestamp
   - Download action

**Data Flow - Dashboard Stats:**
```
1. PAGE LOAD
   ├─> useQuery: ['dashboard-stats']
   ├─> API Call: GET /api/dashboard/stats
   │
   ├─> Backend: dashboardController.getStats()
   │   ├─> Read from uploads/analysis/*.json
   │   ├─> Parse all scan results
   │   ├─> Calculate aggregates:
   │   │   ├─> totalChecks: Count unique check IDs
   │   │   ├─> severityData: Group by severity
   │   │   │   └─> { critical: 45, high: 120, medium: 230, low: 150 }
   │   │   ├─> categoryData: Group by category
   │   │   ├─> activeScans: Count running scans
   │   │   ├─> riskScore: Weighted calculation
   │   │   ├─> postureScore: 100 - (riskScore / normalizer)
   │   │   ├─> delta: Compare with previous scan
   │   │   └─> trends: Last 7 days data points
   │   │       └─> [{ timestamp, totalFindings, riskScore, postureScore }]
   │   │
   │   └─> Return: DashboardStats object
   │
   └─> Frontend: Receive data
       ├─> Update component state
       ├─> Trigger chart re-renders
       ├─> Auto-refetch every 5 seconds
       └─> Display metrics

2. POSTURE SCORE CARD
   ├─> Display: stats.postureScore (0-100%)
   ├─> Progress bar: Width = postureScore%
   ├─> Color: Orange (#E8500A)
   └─> Animation: 1s transition

3. FINDINGS DELTA CARD
   ├─> Display: Math.abs(stats.delta)
   ├─> Icon: TrendingUp (red) or TrendingDown (green)
   ├─> Text: "Regression Detected" or "Posture Improved"
   └─> Color: Based on positive/negative delta

4. IDENTITY CHECKS CARD
   ├─> Display: stats.totalChecks
   ├─> Icon: Server (blue)
   └─> Text: "Active Monitoring"

5. CRITICAL EXPOSURE CARD
   ├─> Display: stats.severityData.critical
   ├─> Icon: AlertTriangle (red)
   ├─> Border: Left border-critical
   └─> Text: "Remediation Pending"
```

**Chart Rendering - Security Posture Trend:**
```
1. DATA PREPARATION
   ├─> Source: stats.trends[]
   ├─> Transform: Add formatted date
   │   └─> date: new Date(timestamp).toLocaleDateString()
   └─> Data structure:
       [{
         date: "Mar 25",
         timestamp: 1711324800000,
         totalFindings: 545,
         riskScore: 67,
         postureScore: 87
       }, ...]

2. RECHARTS RENDERING
   ├─> Component: <AreaChart>
   ├─> Data: trendData
   ├─> Dimensions: ResponsiveContainer (100% x 300px)
   ├─> Gradient: linearGradient "colorRisk"
   │   ├─> Start: #E8500A @ 30% opacity
   │   └─> End: #E8500A @ 0% opacity
   ├─> Grid: Dashed horizontal lines
   ├─> X-Axis: date field
   ├─> Y-Axis: Auto-scaled
   ├─> Tooltip: Custom dark theme
   └─> Area: riskScore with orange stroke

3. INTERACTION
   ├─> Hover: Show tooltip with exact values
   ├─> Responsive: Adjusts to container width
   └─> Animation: Smooth transitions
```

**Chart Rendering - Severity Distribution:**
```
1. DATA PREPARATION
   ├─> Source: stats.severityData
   ├─> Transform: Object.entries() to array
   │   └─> Filter: value > 0
   │   └─> Map: { name, value, rawName }
   └─> Example:
       [
         { name: "Critical", value: 45, rawName: "critical" },
         { name: "High", value: 120, rawName: "high" },
         { name: "Medium", value: 230, rawName: "medium" },
         { name: "Low", value: 150, rawName: "low" }
       ]

2. RECHARTS PIE RENDERING
   ├─> Component: <PieChart>
   ├─> Inner radius: 60px (donut chart)
   ├─> Outer radius: 85px
   ├─> Padding angle: 5° between slices
   ├─> Colors: Map rawName to theme colors
   │   ├─> critical: #f85149
   │   ├─> high: #f0883e
   │   ├─> medium: #d29922
   │   └─> low: #58a6ff
   ├─> Center text: Total findings count
   └─> Tooltip: Show severity + count

3. CENTER OVERLAY
   ├─> Position: Absolute center
   ├─> Display: totalFindings (sum of all values)
   ├─> Label: "Total Reports"
   └─> Styling: Large bold number
```

**Recent Activity Table:**
```
1. DATA FETCH
   ├─> useQuery: ['dashboard-recent']
   ├─> API Call: GET /api/dashboard/recent
   │
   ├─> Backend: dashboardController.getRecent()
   │   ├─> Read recent scan files
   │   ├─> Sort by timestamp DESC
   │   ├─> Limit: 10 most recent
   │   └─> Return: RecentScan[]
   │
   └─> Frontend: Display in table

2. TABLE STRUCTURE
   ├─> Columns: ID | Status | Findings | Timestamp | Action
   ├─> Row data:
   │   ├─> ID: scan.id (font-mono)
   │   ├─> Status: "Secured" badge (green)
   │   ├─> Findings: scan.totalFindings (bold)
   │   ├─> Timestamp: Formatted date/time
   │   └─> Action: Download button
   │
   └─> Interactions:
       ├─> Hover: Row highlight
       └─> Click download: Export scan JSON

3. DOWNLOAD ACTION
   ├─> Click: handleDownloadScan(scanId)
   ├─> API Call: GET /reports/export/{scanId}/json
   ├─> Backend: Stream file
   ├─> Frontend: downloadAuthenticated()
   │   ├─> Fetch with Authorization header
   │   ├─> Convert to Blob
   │   ├─> Create download link
   │   └─> Trigger download
   └─> Filename: AD_Suite_Scan_{scanId}.json
```



---

### PAGE 3: NEW SCAN PAGE (`/scans/new`)

**Purpose:** Configure and execute security scans with check selection

**Complete Component Breakdown:**

**Left Panel - Configuration:**
1. Scan Identity Input
2. Scope Summary Display
3. Engage Scan Button
4. Clear Selections Button
5. Active Progress Display

**Right Panel - Check Selection Matrix:**
1. Search Filter Input
2. Category Accordion List
3. Individual Check Cards
4. Bulk Selection Controls

**Data Flow - Complete Scan Execution:**
```
1. INITIAL LOAD
   ├─> useQuery: ['checks']
   ├─> API Call: GET /api/checks
   │
   ├─> Backend: checkController.getAll()
   │   ├─> Read checks.json
   │   ├─> Apply overrides from checks.overrides.json
   │   ├─> Merge generated checks
   │   ├─> Return: { checks: Check[] }
   │   │
   │   └─> Check structure:
   │       {
   │         id: "ACC-001",
   │         name: "Privileged Users adminCount1",
   │         category: "Access_Control",
   │         severity: "high",
   │         engine: "ldap",
   │         description: "...",
   │         remediation: "...",
   │         references: ["..."],
   │         ldapFilter: "(&(objectCategory=person)...)",
   │         propertiesToLoad: ["name", "distinguishedName", ...],
   │         outputProperties: {...}
   │       }
   │
   └─> Frontend: Store in catalogData
       ├─> Group by category
       ├─> Apply search filter
       └─> Render check matrix

2. CHECK SELECTION PROCESS
   ├─> User clicks check card
   ├─> toggleCheck(checkId)
   │   ├─> Get current Set<string>
   │   ├─> Add or remove checkId
   │   └─> Update selectedChecks state
   │
   ├─> Category selection
   │   ├─> toggleCategorySelection(category)
   │   ├─> Get all checks in category
   │   ├─> Check if all selected
   │   ├─> If all selected: Remove all
   │   └─> If not all: Add all + expand category
   │
   └─> Bulk actions
       ├─> selectAll(): Add all check IDs
       └─> deselectAll(): Clear Set

3. SCAN EXECUTION - COMPLETE FLOW
   ├─> User clicks "Engage Scan"
   ├─> handleRunScan()
   │   ├─> Validate: selectedChecks.size > 0
   │   ├─> Generate scanId: Date.now()
   │   ├─> Convert Set to Array: includeCheckIds
   │   │
   │   ├─> Set initial progress:
   │   │   └─> { status: 'starting', message: '...', progress: 0 }
   │   │
   │   └─> executeScanMutation.mutate()
   │
   ├─> API Call: POST /api/scans/{scanId}/execute
   │   └─> Body: {
   │         categories: [],
   │         includeCheckIds: ["ACC-001", "KRB-002", ...]
   │       }
   │
   ├─> Backend: scanController.execute()
   │   ├─> Validate request
   │   ├─> Create scan directory: out/scan-{scanId}/
   │   ├─> Build PowerShell command:
   │   │   └─> Invoke-ADSuiteScan.ps1
   │   │       -ChecksJsonPath checks.json
   │   │       -IncludeCheckId ACC-001,KRB-002,...
   │   │       -OutputDirectory out/scan-{scanId}
   │   │
   │   ├─> Spawn PowerShell process
   │   │   ├─> Use child_process.spawn()
   │   │   ├─> Shell: powershell.exe
   │   │   ├─> Args: ['-File', 'Invoke-ADSuiteScan.ps1', ...]
   │   │   │
   │   │   ├─> STDOUT handler:
   │   │   │   ├─> Parse progress messages
   │   │   │   ├─> Extract percentage
   │   │   │   ├─> Broadcast via WebSocket:
   │   │   │   │   └─> { type: 'scan_update', data: {
   │   │   │   │         status: 'running',
   │   │   │   │         message: 'Executing check ACC-001...',
   │   │   │   │         progress: 45
   │   │   │   │       }}
   │   │   │   └─> Log to winston
   │   │   │
   │   │   ├─> STDERR handler:
   │   │   │   ├─> Log errors
   │   │   │   └─> Broadcast error status
   │   │   │
   │   │   └─> EXIT handler:
   │   │       ├─> Read scan-results.json
   │   │       ├─> Parse findings
   │   │       ├─> Calculate summary
   │   │       ├─> Broadcast completion:
   │   │       │   └─> { type: 'scan_update', data: {
   │   │       │         status: 'completed',
   │   │       │         progress: 100,
   │   │       │         results: {
   │   │       │           scanResultsPath: '...',
   │   │       │           summary: {...},
   │   │       │           graphData: {...}
   │   │       │         }
   │   │       │       }}
   │   │       └─> Return success response
   │   │
   │   └─> Return: { scanId, status: 'started' }
   │
   └─> Frontend: WebSocket updates
       ├─> Receive scan_update messages
       ├─> Update scanProgress state
       ├─> Re-render progress bar
       ├─> On completion:
       │   ├─> Store scanResults
       │   ├─> Show graph visualization
       │   └─> Enable "Deep Analysis" button

4. POWERSHELL EXECUTION - INTERNAL FLOW
   ├─> Invoke-ADSuiteScan.ps1 starts
   │   ├─> Load checks catalog
   │   ├─> Apply overrides
   │   ├─> Filter by includeCheckIds
   │   ├─> Validate catalog structure
   │   │
   │   ├─> For each check:
   │   │   ├─> Load ADSI module
   │   │   ├─> Connect to LDAP
   │   │   │   └─> [ADSI]"LDAP://{server}/{searchBase}"
   │   │   │
   │   │   ├─> Execute LDAP query
   │   │   │   ├─> Filter: check.ldapFilter
   │   │   │   ├─> Properties: check.propertiesToLoad
   │   │   │   ├─> Scope: Subtree/OneLevel/Base
   │   │   │   └─> PageSize: 1000
   │   │   │
   │   │   ├─> Process results
   │   │   │   ├─> Map properties to outputProperties
   │   │   │   ├─> Count findings
   │   │   │   ├─> Calculate check score
   │   │   │   └─> Store in results array
   │   │   │
   │   │   ├─> Write progress
   │   │   │   └─> Write-Host "Progress: 45%"
   │   │   │
   │   │   └─> Handle errors
   │   │       ├─> Catch LDAP errors
   │   │       ├─> Log to error.log
   │   │       └─> Continue or stop based on -StopOnFirstError
   │   │
   │   ├─> Calculate aggregate scores
   │   │   ├─> globalRaw: Sum of all check scores
   │   │   ├─> globalScore: globalRaw / scoringNormalizer
   │   │   ├─> globalRiskBand: Critical/High/Medium/Low
   │   │   ├─> scoreByCategory: Group scores
   │   │   └─> byCategory: Count checks per category
   │   │
   │   ├─> Generate outputs
   │   │   ├─> scan-results.json:
   │   │   │   {
   │   │   │     schemaVersion: 1,
   │   │   │     meta: {
   │   │   │       Timestamp: "2026-04-02T...",
   │   │   │       Domain: "technieum.com",
   │   │   │       DomainDN: "DC=technieum,DC=com",
   │   │   │       TargetServer: "192.168.1.100",
   │   │   │       ChecksJsonPath: "checks.json",
   │   │   │       OutputDirectory: "out/scan-1234567890"
   │   │   │     },
   │   │   │     aggregate: {
   │   │   │       checksRun: 150,
   │   │   │       checksWithFindings: 87,
   │   │   │       checksWithErrors: 2,
   │   │   │       totalFindings: 545,
   │   │   │       globalRaw: 3350,
   │   │   │       globalScore: 67,
   │   │   │       globalRiskBand: "High",
   │   │   │       scoreByCategory: {...}
   │   │   │     },
   │   │   │     byCategory: {...},
   │   │   │     results: [
   │   │   │       {
   │   │   │         CheckId: "ACC-001",
   │   │   │         CheckName: "Privileged Users adminCount1",
   │   │   │         Category: "Access_Control",
   │   │   │         Severity: "high",
   │   │   │         Result: "fail",
   │   │   │         FindingCount: 12,
   │   │   │         CheckScore: 120,
   │   │   │         DurationMs: 1250,
   │   │   │         Error: null,
   │   │   │         Description: "...",
   │   │   │         Remediation: "...",
   │   │   │         References: ["..."],
   │   │   │         Findings: [
   │   │   │           {
   │   │   │             Name: "john.doe",
   │   │   │             DistinguishedName: "CN=John Doe,OU=Users,DC=...",
   │   │   │             SamAccountName: "john.doe",
   │   │   │             AdminCount: 1,
   │   │   │             UserAccountControl: 512,
   │   │   │             ObjectClass: "user",
   │   │   │             WhenCreated: "2024-01-15T...",
   │   │   │             WhenChanged: "2026-03-20T..."
   │   │   │           },
   │   │   │           ...
   │   │   │         ],
   │   │   │         SourcePath: "Access_Control/ACC-001.../adsi.ps1",
   │   │   │         ScoreWeight: 10
   │   │   │       },
   │   │   │       ...
   │   │   │     ]
   │   │   │   }
   │   │   │
   │   │   ├─> findings.csv:
   │   │   │   └─> Flattened findings with all properties
   │   │   │
   │   │   └─> report.html:
   │   │       └─> HTML report with charts and tables
   │   │
   │   └─> Exit with code 0 (success) or 1 (error)

5. WEBSOCKET REAL-TIME UPDATES
   ├─> Frontend establishes WebSocket connection
   │   ├─> URL: ws://localhost:3001
   │   ├─> Protocol: WebSocket
   │   └─> Auto-reconnect on disconnect
   │
   ├─> Backend WebSocket server
   │   ├─> Listen on port 3001
   │   ├─> Maintain client connections
   │   ├─> Broadcast to all clients:
   │   │   └─> ws.clients.forEach(client => {
   │   │         if (client.readyState === WebSocket.OPEN) {
   │   │           client.send(JSON.stringify(message));
   │   │         }
   │   │       })
   │   │
   │   └─> Message types:
   │       ├─> scan_update: Progress updates
   │       ├─> scan_complete: Scan finished
   │       ├─> scan_error: Error occurred
   │       └─> terminal_output: Terminal data
   │
   └─> Frontend message handler
       ├─> Parse JSON message
       ├─> Switch on message.type
       ├─> Update component state
       └─> Trigger re-render

6. GRAPH VISUALIZATION - RESULTS DISPLAY
   ├─> scanResults.graphData structure:
   │   {
   │     nodes: [
   │       {
   │         id: "user_john.doe",
   │         label: "john.doe",
   │         type: "user",
   │         properties: {...}
   │       },
   │       {
   │         id: "group_Domain Admins",
   │         label: "Domain Admins",
   │         type: "group",
   │         properties: {...}
   │       },
   │       ...
   │     ],
   │     edges: [
   │       {
   │         id: "edge_1",
   │         source: "user_john.doe",
   │         target: "group_Domain Admins",
   │         label: "MemberOf",
   │         weight: 1
   │       },
   │       ...
   │     ]
   │   }
   │
   ├─> GraphVisualizer component
   │   ├─> Use Sigma.js library
   │   ├─> Create graph instance
   │   ├─> Add nodes with positions
   │   ├─> Add edges with colors
   │   ├─> Apply force-directed layout
   │   ├─> Enable zoom/pan controls
   │   └─> Add click handlers
   │
   └─> Interaction features
       ├─> Click node: Show details
       ├─> Hover edge: Highlight path
       ├─> Zoom: Mouse wheel
       ├─> Pan: Click and drag
       └─> Reset: Double-click background
```

**Check Selection UI - Detailed Breakdown:**
```
1. CATEGORY ACCORDION
   ├─> Header row:
   │   ├─> Checkbox: Select/deselect all in category
   │   ├─> Category name: "Access_Control" → "Access Control"
   │   ├─> Count: "(12/45)" selected/total
   │   └─> Expand icon: ChevronDown/ChevronRight
   │
   ├─> Expanded state:
   │   └─> Check cards list
   │       ├─> Each check card:
   │       │   ├─> Checkbox: Individual selection
   │       │   ├─> Check ID: "ACC-001" (orange, mono font)
   │       │   ├─> Severity badge: Color-coded pill
   │       │   ├─> Engine label: "ldap" (gray, small)
   │       │   ├─> Check name: Bold title
   │       │   └─> Description: Truncated preview
   │       │
   │       └─> Hover effects:
   │           ├─> Background: Orange tint
   │           └─> Cursor: Pointer
   │
   └─> Collapsed state:
       └─> Only header visible

2. SEARCH FILTER
   ├─> Input field with search icon
   ├─> Placeholder: "Filter catalog..."
   ├─> onChange: Update searchTerm state
   ├─> Filter logic:
   │   └─> Match against:
   │       ├─> check.id (case-insensitive)
   │       ├─> check.name (case-insensitive)
   │       └─> check.description (case-insensitive)
   │
   └─> Real-time filtering:
       ├─> useMemo: Recompute on searchTerm change
       └─> Update groupedChecks

3. SEVERITY BADGES
   ├─> Colors:
   │   ├─> Critical: Red (#f85149)
   │   ├─> High: Orange (#f0883e)
   │   ├─> Medium: Yellow (#d29922)
   │   └─> Low: Blue (#58a6ff)
   │
   └─> Styling:
       ├─> Border: Matching color @ 30% opacity
       ├─> Background: Matching color @ 5% opacity
       ├─> Text: Matching color
       └─> Font: Bold, uppercase, 8px
```


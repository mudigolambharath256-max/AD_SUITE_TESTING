# Run Scans Page - Complete Technical Analysis
## AD Security Suite Web Application

**Generated**: 2024
**Purpose**: Comprehensive documentation of the scan execution interface

---

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [State Management](#state-management)
4. [Configuration Components](#configuration-components)
5. [Scan Execution Flow](#scan-execution-flow)
6. [Backend Implementation](#backend-implementation)
7. [Real-Time Communication](#real-time-communication)
8. [Results Display](#results-display)
9. [Error Handling](#error-handling)
10. [Advanced Features](#advanced-features)

---

## Overview

### Purpose
The Run Scans page is the primary interface for executing Active Directory security checks.
It provides:
- Suite root path validation
- Target domain/server configuration
- Execution engine selection
- Check selection interface
- Real-time scan progress monitoring
- Results visualization and export

### Key Features
- **5 Execution Engines**: ADSI, PowerShell, C#, CMD, Combined
- **833 Security Checks**: Across 18 categories
- **Real-Time Progress**: SSE-based live updates
- **Target Flexibility**: Auto-discover, domain-targeted, or explicit IP
- **Export Formats**: JSON, CSV, PDF
- **Diagnostics**: Single-check testing with full output
- **State Persistence**: Scan configuration survives page refresh

---

## Architecture

### Component Hierarchy

```
RunScans (Main Page)
├── Configuration Panel (Left)
│   ├── Suite Root Path Validator
│   ├── Target Configuration
│   │   ├── Domain Name Input
│   │   ├── Server IP Input
│   │   ├── Connection Mode Badge
│   │   └── Test Connection Button
│   ├── Engine Selector
│   ├── Scan Diagnostics
│   └── Check Selector
│       ├── Search Bar
│       ├── Select All / Clear All
│       └── Category Tree
│           └── Individual Checks
└── Execution Panel (Right)
    ├── Idle State (Ready to Scan)
    ├── Running State
    │   ├── Scan Progress
    │   └── Live Terminal
    └── Complete State
        ├── Summary Statistics
        ├── Findings Table
        └── Terminal Output (Collapsible)

```

### File Structure

**Frontend**:
- `ad-suite-web/frontend/src/pages/RunScans.jsx` - Main page component
- `ad-suite-web/frontend/src/hooks/useScan.js` - Scan state management hook
- `ad-suite-web/frontend/src/components/CheckSelector.jsx` - Check selection UI
- `ad-suite-web/frontend/src/components/EngineSelector.jsx` - Engine selection UI
- `ad-suite-web/frontend/src/components/ScanProgress.jsx` - Progress display
- `ad-suite-web/frontend/src/components/FindingsTable.jsx` - Results table
- `ad-suite-web/frontend/src/components/Terminal.jsx` - Terminal output
- `ad-suite-web/frontend/src/components/ScanDiagnostics.jsx` - Diagnostic tool
- `ad-suite-web/frontend/src/components/PsTerminalDrawer.jsx` - Interactive PowerShell

**Backend**:
- `ad-suite-web/backend/routes/scan.js` - Scan API endpoints
- `ad-suite-web/backend/services/executor.js` - Scan execution engine
- `ad-suite-web/backend/services/db.js` - Database operations

---

## State Management

### Zustand Store (useAppStore)

**Persisted State** (localStorage):
```javascript
{
  suiteRoot: string,              // Path to AD-Suite-scripts-main
  suiteRootValid: boolean,        // Validation status
  domain: string,                 // Target domain FQDN
  serverIp: string,               // Target DC/server IP
  engine: string,                 // Selected execution engine
  selectedCheckIds: string[],     // Array of check IDs
  availableChecks: object[],      // Discovered checks from suite
  
  // Scan execution state
  activeScanId: string | null,    // Current scan UUID
  scanStatus: string,             // idle|running|complete|error|aborted
  progress: object,               // { current, total, currentCheck }
  scanSummary: object,            // { total, duration, bySeverity }
  scanError: string | null        // Error message if failed
}
```


**Findings Store** (useFindingsStore - IndexedDB):
```javascript
{
  findings: array,     // Current scan findings
  logLines: array      // Terminal output lines
}
```

**Why IndexedDB for Findings?**
- Large datasets (thousands of findings)
- Survives page refresh
- Better performance than localStorage
- Async operations don't block UI

**Store Hydration**:
```javascript
useEffect(() => {
  const timer = setTimeout(() => setIsStoreReady(true), 50);
  return () => clearTimeout(timer);
}, []);
```
- 50ms delay prevents flash of empty content
- Zustand handles hydration internally
- Loading spinner shown during hydration

---

## Configuration Components

### 1. Suite Root Path Validation

**Purpose**: Verify the path contains valid AD Suite scripts

**UI Elements**:
- Text input for path
- Validate button
- Status indicator (✓ Valid)
- Error/success message

**Validation Flow**:
```javascript
const validateSuiteRoot = async () => {
  if (!suiteRoot.trim()) {
    setValidation({ valid: false, error: 'Suite root path is required' });
    return;
  }

  const response = await fetch('/api/scan/discover-checks', {
    method: 'POST',
    body: JSON.stringify({ suiteRoot })
  });

  const result = await response.json();

  if (result.valid && result.checks.length > 0) {
    setValidation({
      valid: true,
      message: `Found ${result.totalChecks} checks across ${result.categoriesFound} categories`
    });
    store.setSuiteRootValid(true);
    store.setAvailableChecks(result.checks);
  } else {
    setValidation({ valid: false, error: result.error });
    store.setSuiteRootValid(false);
  }
};
```

**Backend Discovery** (`POST /api/scan/discover-checks`):
```javascript
async function discoverChecks(suiteRoot) {
  const discoveredChecks = [];

  for (const category of categories) {
    const categoryPath = path.join(suiteRoot, category.id);
    const folders = fs.readdirSync(categoryPath);

    for (const folder of folders) {
      const match = folder.match(/^([A-Z]+)-(\d+)/);
      if (match) {
        const checkId = `${match[1]}-${match[2]}`;
        const checkName = folder.substring(checkId.length + 1);
        discoveredChecks.push({ id: checkId, name: checkName, category: category.id });
      }
    }
  }

  return { valid: true, checks: discoveredChecks, totalChecks: discoveredChecks.length };
}
```


---

### 2. Target Configuration

**Purpose**: Specify which Active Directory domain/server to scan

**Connection Modes**:

| Mode | Domain | Server IP | LDAP URL | Use Case |
|------|--------|-----------|----------|----------|
| Auto-discover | Empty | Empty | `LDAP://RootDSE` | Scan local domain |
| Domain-targeted | Set | Empty | `LDAP://[DC from DNS]/DC=domain,DC=local` | Specific domain via DNS |
| Direct | Empty | Set | `LDAP://192.168.1.10/[auto NC]` | Specific DC, auto-discover domain |
| Explicit | Set | Set | `LDAP://192.168.1.10/DC=domain,DC=local` | Full control |

**FQDN to DN Conversion**:
```javascript
const fqdnToDN = (fqdn) => {
  return fqdn.split('.').map(part => `DC=${part}`).join(',');
};

// Example: "corp.contoso.com" → "DC=corp,DC=contoso,DC=com"
```

**Connection Mode Badge**:
```javascript
const getConnectionMode = () => {
  if (store.serverIp && store.domain) {
    return { 
      icon: Target, 
      text: 'Explicit', 
      desc: `LDAP://${store.serverIp}/${fqdnToDN(store.domain)}` 
    };
  }
  if (store.serverIp && !store.domain) {
    return { 
      icon: Zap, 
      text: 'Direct', 
      desc: `LDAP://${store.serverIp}/[auto-discovered NC]` 
    };
  }
  if (!store.serverIp && store.domain) {
    return { 
      icon: Search, 
      text: 'Domain-targeted', 
      desc: `LDAP://[DC from DNS]/${fqdnToDN(store.domain)}` 
    };
  }
  return { 
    icon: ZapOff, 
    text: 'Auto-discover', 
    desc: "uses machine's default domain (LDAP://RootDSE)" 
  };
};
```

**Test Connection** (`POST /api/scan/validate-target`):
```javascript
const testTarget = async () => {
  const response = await fetch('/api/scan/validate-target', {
    method: 'POST',
    body: JSON.stringify({ domain: store.domain, serverIp: store.serverIp })
  });
  
  const result = await response.json();
  
  if (result.valid) {
    setTargetValidation({ valid: true, domainNC: result.domainNC });
  } else {
    setTargetValidation({ valid: false, error: result.error });
  }
};
```

**Backend Validation**:
```powershell
$root = [ADSI]'LDAP://192.168.1.10/RootDSE'
$nc = $root.defaultNamingContext.ToString()
if ($nc) { 
  Write-Output "OK:$nc" 
} else { 
  Write-Error "Empty NC" 
}
```


---

### 3. Execution Engine Selection

**Available Engines**:

| Engine | File | Description | Speed | Compatibility |
|--------|------|-------------|-------|---------------|
| ADSI | `adsi.ps1` | Direct ADSI queries | Fast | Best |
| PowerShell | `powershell.ps1` | AD PowerShell module | Medium | Requires RSAT |
| C# | `csharp.cs` | Compiled .NET code | Fastest | Requires .NET Framework |
| CMD | `cmd.bat` | Batch scripts | Slow | Universal |
| Combined | `combined_multiengine.ps1` | Multi-engine fallback | Variable | Best coverage |

**Engine Selector Component**:
```jsx
<EngineSelector
  selectedEngine={store.engine}
  onEngineChange={(engine) => store.setEngine(engine)}
  disabled={!!activeScanId}
/>
```

**Implementation**:
```jsx
const EngineSelector = ({ selectedEngine, onEngineChange, disabled }) => {
  return (
    <div className="flex flex-wrap gap-2">
      {ENGINES.map((engine) => (
        <button
          key={engine.id}
          onClick={() => !disabled && onEngineChange(engine.id)}
          className={selectedEngine === engine.id ? 'bg-accent-primary' : 'bg-bg-tertiary'}
        >
          {engine.label}
        </button>
      ))}
    </div>
  );
};
```

**Engine Compatibility Check**:
```javascript
if (store.engine === 'cmd' && (store.domain || store.serverIp)) {
  alert('Domain/IP targeting is not supported for CMD engine.');
  return;
}
```

---

### 4. Check Selector

**Purpose**: Select which security checks to run

**Features**:
- Search by check ID or name
- Category-based grouping
- Select all / Clear all
- Individual check selection
- Category-level selection (with indeterminate state)
- Expandable/collapsible categories

**State Management**:
```javascript
const [searchTerm, setSearchTerm] = useState('');
const [expandedCategories, setExpandedCategories] = useState(new Set());
```

**Check Discovery**:
```javascript
// Checks are discovered during suite root validation
const discoverResult = await fetch('/api/scan/discover-checks', {
  method: 'POST',
  body: JSON.stringify({ suiteRoot })
});

// Result format:
{
  valid: true,
  checks: [
    {
      id: "AUTH-001",
      name: "Accounts Without Kerberos Pre-Auth",
      category: "Authentication",
      categoryDisplay: "Authentication",
      folder: "AUTH-001_Accounts_Without_Kerberos_Pre-Auth"
    }
  ],
  totalChecks: 833,
  categoriesFound: 18
}
```


**Category Grouping**:
```javascript
const checksByCategory = availableChecks.reduce((acc, check) => {
  if (!acc[check.category]) {
    acc[check.category] = {
      id: check.category,
      display: check.categoryDisplay,
      checks: []
    };
  }
  acc[check.category].checks.push(check);
  return acc;
}, {});
```

**Selection State**:
```javascript
const getCategorySelectionState = (category) => {
  const categoryCheckIds = category.checks.map(c => c.id);
  const selectedCount = categoryCheckIds.filter(checkId => 
    selectedChecks.has(checkId)
  ).length;

  if (selectedCount === 0) return 'none';
  if (selectedCount === categoryCheckIds.length) return 'all';
  return 'indeterminate';
};
```

**Indeterminate Checkbox**:
```jsx
<input
  type="checkbox"
  checked={selectionState === 'all'}
  ref={input => {
    if (input) input.indeterminate = selectionState === 'indeterminate';
  }}
  onChange={(e) => handleCategorySelect(category, e.target.checked)}
/>
```

**Search Filtering**:
```javascript
const filteredCategories = categories.filter(category => {
  if (!searchTerm) return true;

  const categoryMatch = category.display.toLowerCase()
    .includes(searchTerm.toLowerCase());
  const checkMatch = category.checks.some(check =>
    check.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
    check.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return categoryMatch || checkMatch;
});
```

---

## Scan Execution Flow

### Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. USER CLICKS "RUN SCAN"                                   │
│    • Validates suite root                                   │
│    • Validates check selection                              │
│    • Validates engine compatibility                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. FRONTEND: startScan()                                    │
│    • Clear previous findings                                │
│    • POST /api/scan/run                                     │
│    • Receive scanId                                         │
│    • Connect to SSE stream                                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. BACKEND: Create Scan Record                              │
│    • Generate UUID                                          │
│    • Insert into database                                   │
│    • Set status = 'running'                                 │
│    • Return scanId to frontend                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. BACKEND: executor.runScan()                              │
│    • Create BloodHound export directory                     │
│    • Set environment variables                              │
│    • Loop through checkIds                                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. FOR EACH CHECK:                                          │
│    • Resolve script path                                    │
│    • Apply domain/IP injection (if specified)               │
│    • Spawn PowerShell/CMD process                           │
│    • Stream stdout/stderr to SSE                            │
│    • Parse JSON output                                      │
│    • Insert findings into database                          │
│    • Emit progress event                                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. FRONTEND: SSE Event Handling                             │
│    • progress → Update progress bar                         │
│    • log → Append to terminal                               │
│    • finding → Add to findings list                         │
│    • complete → Show results                                │
│    • error → Display error message                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. SCAN COMPLETE                                            │
│    • Generate summary statistics                            │
│    • Export JSON/CSV/PDF                                    │
│    • Update database status                                 │
│    • Close SSE connection                                   │
│    • Display results UI                                     │
└─────────────────────────────────────────────────────────────┘
```


---

### Frontend Scan Initiation

**useScan Hook**:
```javascript
const startScan = useCallback(async () => {
  if (!store.suiteRootValid) throw new Error('Suite root not validated');
  if (store.selectedCheckIds.length === 0) throw new Error('No checks selected');

  findingsStore.clearFindings();

  const response = await fetch('/api/scan/run', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      checkIds: store.selectedCheckIds,
      engine: store.engine,
      suiteRoot: store.suiteRoot,
      domain: store.domain || null,
      serverIp: store.serverIp || null,
    })
  });

  const { scanId } = await response.json();

  store.setActiveScan(scanId);
  connectSSE(scanId);
  return scanId;
}, [store, findingsStore, connectSSE]);
```

**Button Handler**:
```javascript
const handleRunScan = async () => {
  if (selectedCheckIds.length === 0) {
    alert('Please select at least one check to run');
    return;
  }

  if (!store.suiteRootValid) {
    alert('Please validate suite root path before running scans');
    return;
  }

  if (store.engine === 'cmd' && (store.domain || store.serverIp)) {
    alert('Domain/IP targeting is not supported for CMD engine.');
    return;
  }

  try {
    await startScan();
  } catch (error) {
    alert(`Failed to start scan: ${error.message}`);
  }
};
```

---

### Backend Scan Execution

**POST /api/scan/run**:
```javascript
router.post('/run', async (req, res) => {
  const { suiteRoot, checkIds, engine, domain, serverIp } = req.body;

  // Validation
  if (!suiteRoot || !checkIds || !engine) {
    return res.status(400).json({ error: 'Missing required parameters' });
  }

  // Check if scan already running
  if (executor.isScanning()) {
    return res.status(409).json({ error: 'A scan is already running' });
  }

  const scanId = uuidv4();

  // Create scan record
  db.createScan({
    id: scanId,
    timestamp: Date.now(),
    engine,
    suiteRoot,
    domain,
    serverIp,
    checkIds,
    checkCount: checkIds.length,
    status: 'running'
  });

  // Run scan asynchronously
  setImmediate(() => {
    executor.runScan({ scanId, checkIds, engine, suiteRoot, domain, serverIp })
      .catch(err => {
        console.error('Scan execution error:', err);
        db.updateScanStatus(scanId, 'error');
      });
  });

  res.json({ scanId });
});
```


**Executor runScan()**:
```javascript
async function runScan({ scanId, checkIds, engine, suiteRoot, domain, serverIp }) {
  const startTime = Date.now();
  _activeScanId = scanId;

  // Create BloodHound export directory
  const bloodhoundDir = path.join(REPORTS_DIR, scanId, 'bloodhound');
  fs.mkdirSync(bloodhoundDir, { recursive: true });

  // Set environment variables for scripts
  process.env.ADSUITE_SESSION_ID = scanId;
  process.env.ADSUITE_OUTPUT_ROOT = REPORTS_DIR;

  db.updateScanStatus(scanId, 'running');

  let completedCount = 0;
  const total = checkIds.length;
  const allFindings = [];

  for (const checkId of checkIds) {
    if (!isScanning()) break; // Aborted

    // Resolve script path
    const resolved = resolveScriptPath(suiteRoot, checkId, engine);
    if (!resolved) {
      emitSSE(scanId, { type: 'log', line: `[SKIP] ${checkId}: script not found` });
      completedCount++;
      continue;
    }

    const { scriptPath, category } = resolved;

    // Emit progress
    emitSSE(scanId, {
      type: 'progress',
      progress: { current: completedCount, total, currentCheckId: checkId }
    });

    // Apply domain/IP injection
    const execScriptPath = (domain || serverIp)
      ? await injectAndWriteTempScript(scriptPath, domain, serverIp, engine)
      : scriptPath;

    // Build command
    const { cmd, args } = engine === 'cmd'
      ? { cmd: 'cmd.exe', args: ['/c', execScriptPath] }
      : buildPsCommand(execScriptPath, engine);

    // Execute
    let stdoutBuffer = '';
    await new Promise((resolve) => {
      const proc = spawn(cmd, args, { shell: false, timeout: 120000 });
      _activeScanProcess = proc;

      proc.stdout.on('data', (chunk) => {
        stdoutBuffer += chunk.toString();
        emitSSE(scanId, { type: 'log', line: chunk.toString() });
      });

      proc.on('close', (code) => {
        _activeScanProcess = null;

        // Parse findings
        const findings = parseScriptOutput(stdoutBuffer, checkId, category);
        allFindings.push(...findings);

        // Store in database
        findings.forEach(f => db.insertFinding({ ...f, scanId, id: uuidv4() }));

        // Save raw output
        saveRawCheckOutput(scanId, checkId, stdoutBuffer, findings);

        completedCount++;
        resolve();
      });
    });
  }

  // Finalize
  const duration = Date.now() - startTime;
  const summary = buildSummary(allFindings, duration);

  db.finalizeScan(scanId, allFindings.length, duration, 'completed');
  await writeExportFiles(scanId, allFindings);

  emitSSE(scanId, { type: 'complete', summary });
  _activeScanId = null;
}
```


---

## Real-Time Communication

### Server-Sent Events (SSE)

**Why SSE?**
- Unidirectional server → client
- Automatic reconnection
- Simple HTTP-based
- No WebSocket complexity
- Perfect for progress updates

**Frontend SSE Connection**:
```javascript
const connectSSE = useCallback((scanId) => {
  if (sseRef.current) sseRef.current.close();

  let retryDelay = 100;
  const connect = () => {
    const es = new EventSource(`/api/scan/stream/${scanId}`);
    sseRef.current = es;

    es.onmessage = (e) => {
      const event = JSON.parse(e.data);
      retryDelay = 100; // Reset on successful message

      if (event.type === 'progress') {
        store.updateProgress(event.progress);
      }
      if (event.type === 'log') {
        findingsStore.appendLog(event.line);
      }
      if (event.type === 'finding') {
        findingsStore.addFinding(event.finding);
      }
      if (event.type === 'complete') {
        store.setScanStatus('complete');
        store.setScanSummary(event.summary);
        es.close();
      }
      if (event.type === 'error') {
        store.setScanError(event.message);
        es.close();
      }
    };

    es.onerror = () => {
      es.close();
      if (store.scanStatus === 'running') {
        // Reconnect with exponential backoff
        retryDelay = Math.min(retryDelay * 2, 5000);
        setTimeout(connect, retryDelay);
      }
    };
  };
  connect();
}, [store, findingsStore]);
```

**Backend SSE Endpoint** (`GET /api/scan/stream/:scanId`):
```javascript
router.get('/stream/:scanId', (req, res) => {
  const { scanId } = req.params;

  // Set SSE headers
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');
  res.flushHeaders();

  // Register client
  executor.registerSSEClient(scanId, res);

  // If scan already complete, send final data
  const scan = db.getScan(scanId);
  if (scan && scan.status === 'completed') {
    const findings = db.getScanFindings(scanId);
    const summary = {
      total: findings.length,
      duration: `${Math.floor(scan.duration_ms / 1000)}s`,
      bySeverity: db.getSeveritySummaryForScan(scanId)
    };
    res.write(`data: ${JSON.stringify({ type: 'complete', summary })}\n\n`);
    return res.end();
  }

  // Cleanup on disconnect
  req.on('close', () => {
    executor.unregisterSSEClient(scanId);
  });
});
```

**SSE Event Types**:

| Type | Payload | Purpose |
|------|---------|---------|
| `progress` | `{ current, total, currentCheckId }` | Update progress bar |
| `log` | `{ line }` | Append to terminal |
| `finding` | `{ finding }` | Add to findings list |
| `complete` | `{ summary }` | Scan finished successfully |
| `error` | `{ message }` | Scan failed |
| `aborted` | `{}` | User aborted scan |

**Emitting Events**:
```javascript
function emitSSE(scanId, event) {
  const client = sseClients.get(scanId);
  if (client && !client.writableEnded) {
    client.write(`data: ${JSON.stringify(event)}\n\n`);
  }
}
```


---

## Results Display

### Scan States

**1. Idle State**:
```jsx
{scanStatus === 'idle' && (
  <div className="card">
    <div className="text-center py-12">
      <SvgIcon name="7x24h" size={64} className="mx-auto text-text-muted mb-4" />
      <h3 className="text-xl font-semibold text-text-primary mb-2">Ready to Scan</h3>
      <p className="text-text-secondary mb-6">
        Configure your scan settings and click Run Scan to begin
      </p>
      <button onClick={handleRunScan} className="btn-primary">
        <Play className="w-4 h-4" />
        Run Scan
      </button>
    </div>
  </div>
)}
```

**2. Running State**:
```jsx
{scanStatus === 'running' && (
  <>
    <div className="card">
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-semibold text-text-primary">Scan in Progress</h3>
        <button onClick={handleAbortScan} className="btn-danger">
          <Square className="w-4 h-4" />
          Abort Scan
        </button>
      </div>
      <ScanProgress
        scan={{ status: scanStatus, id: activeScanId }}
        progress={progress}
        logs={logLines}
      />
    </div>

    <div className="card">
      <Terminal lines={logLines} isRunning={true} height={320} />
    </div>
  </>
)}
```

**3. Complete State**:
```jsx
{scanStatus === 'complete' && (
  <>
    <div className="card">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="font-semibold text-text-primary">Scan Complete</h3>
          <p className="text-sm text-text-secondary mt-1">
            {scanSummary.total} findings in {scanSummary.duration}
          </p>
        </div>
        <div className="flex gap-2">
          <button onClick={() => handleExport('json')} className="btn-secondary">
            <Download className="w-4 h-4" />
            JSON
          </button>
          <button onClick={() => handleExport('csv')} className="btn-secondary">
            <Download className="w-4 h-4" />
            CSV
          </button>
        </div>
      </div>

      {/* Severity Summary */}
      <div className="grid grid-cols-4 gap-4 mb-4">
        <div className="bg-severity-critical/10 rounded p-3">
          <div className="text-2xl font-bold text-severity-critical">
            {scanSummary.bySeverity?.Critical || 0}
          </div>
          <div className="text-xs text-text-secondary">Critical</div>
        </div>
        {/* HIGH, MEDIUM, LOW cards... */}
      </div>
    </div>

    {/* Findings Table */}
    {findings.length > 0 && (
      <div className="card">
        <h3 className="font-semibold text-text-primary mb-3">Findings</h3>
        <FindingsTable findings={findings} />
      </div>
    )}
  </>
)}
```

---

### Progress Display

**ScanProgress Component**:
```jsx
<div className="card">
  {/* Progress Bar */}
  <div className="progress-bar">
    <div 
      className="progress-fill"
      style={{ width: `${(progress.current / progress.total) * 100}%` }}
    ></div>
  </div>
  
  <div className="flex items-center justify-between text-sm">
    <span>{progress.current} / {progress.total} checks</span>
    <span>{progress.findingCount} findings</span>
  </div>

  {/* Current Check */}
  {progress.currentCheck && (
    <div className="p-3 bg-bg-tertiary rounded-lg">
      <div className="text-sm text-text-secondary">Currently Running:</div>
      <div className="font-mono text-accent-primary">
        {progress.currentCheck}
      </div>
    </div>
  )}
</div>
```


---

### Terminal Output

**Terminal Component**:
```jsx
const Terminal = ({ lines, isRunning, height = 240 }) => {
  return (
    <div 
      className="bg-bg-primary border border-border rounded-lg p-3 overflow-y-auto font-mono text-xs"
      style={{ height: `${height}px` }}
    >
      {lines.map((line, index) => (
        <div key={index} className="text-text-secondary mb-1">
          <span className="text-text-muted">
            [{new Date(line.timestamp).toLocaleTimeString()}]
          </span>{' '}
          {line.message}
        </div>
      ))}
      {isRunning && (
        <div className="flex items-center gap-2 text-accent-primary">
          <div className="w-2 h-2 bg-accent-primary rounded-full animate-pulse"></div>
          <span>Running...</span>
        </div>
      )}
    </div>
  );
};
```

**Log Line Format**:
```javascript
{
  timestamp: Date.now(),
  message: "[AUTH-001] Starting — C:\\ADSuite\\Authentication\\AUTH-001\\adsi.ps1"
}
```

**Collapsible Terminal** (Complete State):
```jsx
{logLines.length > 0 && (
  <div className="card">
    <button
      onClick={() => setShowTerminal(!showTerminal)}
      className="flex items-center justify-between w-full"
    >
      <h3 className="font-semibold text-text-primary">Terminal Output</h3>
      {showTerminal ? <ChevronUp /> : <ChevronDown />}
    </button>
    {showTerminal && (
      <div className="mt-3">
        <Terminal lines={logLines} isRunning={false} height={240} />
      </div>
    )}
  </div>
)}
```

---

### Findings Table

**FindingsTable Component**:
```jsx
<FindingsTable
  findings={findings}
  loading={false}
  filters={{}}
  onFiltersChange={() => {}}
/>
```

**Table Columns**:
- Severity badge
- Check ID
- Check Name
- Object Name
- Distinguished Name
- MITRE ATT&CK ID
- Details (expandable JSON)

**Severity Badge**:
```jsx
<span className={`severity-badge severity-${finding.severity.toLowerCase()}`}>
  {finding.severity}
</span>
```

---

## Error Handling

### Validation Errors

**Suite Root Not Validated**:
```javascript
if (!store.suiteRootValid) {
  alert('Please validate suite root path before running scans');
  return;
}
```

**No Checks Selected**:
```javascript
if (selectedCheckIds.length === 0) {
  alert('Please select at least one check to run');
  return;
}
```

**Engine Compatibility**:
```javascript
if (store.engine === 'cmd' && (store.domain || store.serverIp)) {
  alert('Domain/IP targeting is not supported for CMD engine.\n' +
        'Switch to ADSI, PowerShell, or Combined for targeted scans.');
  return;
}
```

---

### Scan Execution Errors

**Concurrent Scan Prevention**:
```javascript
if (executor.isScanning()) {
  return res.status(409).json({ error: 'A scan is already running' });
}
```

**Script Not Found**:
```javascript
const resolved = resolveScriptPath(suiteRoot, checkId, engine);
if (!resolved) {
  emitSSE(scanId, {
    type: 'log',
    line: `[SKIP] ${checkId}: script not found for engine '${engine}'`
  });
  completedCount++;
  continue;
}
```

**Process Spawn Error**:
```javascript
proc.on('error', (err) => {
  emitSSE(scanId, {
    type: 'log',
    line: `[${checkId}] Process error: ${err.message}`
  });
  completedCount++;
  resolve();
});
```

---

### Zero Findings Handling

**Complete with No Findings**:
```jsx
{findings.length === 0 && scanStatus === 'completed' && (
  <div className="card">
    <div className="text-center py-12">
      <CheckCircle className="w-16 h-16 mx-auto text-text-muted mb-4" />
      <h3 className="text-xl font-semibold text-text-primary mb-2">
        Scan Complete — 0 Findings
      </h3>
      <div className="text-text-secondary mb-6 max-w-2xl mx-auto text-left">
        <p className="mb-3">This can mean:</p>
        <ul className="list-disc list-inside space-y-2 text-sm">
          <li className="text-green-400">
            ✓ No vulnerable objects exist in your AD environment
          </li>
          <li className="text-yellow-400">
            ✗ The machine is not domain-joined (scripts return empty)
          </li>
          <li className="text-yellow-400">
            ✗ The suite root path is wrong (scripts not found)
          </li>
        </ul>
        <p className="mt-4 text-sm">
          Use the <span className="font-semibold">Diagnostics panel</span> 
          to run a single check and inspect the raw output.
        </p>
      </div>
    </div>
  </div>
)}
```


---

## Advanced Features

### 1. Scan Diagnostics

**Purpose**: Test single check with full diagnostic output

**Component**: `ScanDiagnostics.jsx`

**Features**:
- Run single check
- View raw stdout/stderr
- See exit code
- Diagnose problems
- Check script availability

**API Endpoint**: `GET /api/scan/diagnose`

**Query Parameters**:
```javascript
{
  suiteRoot: string,
  category: string,
  checkId: string,
  engine: string,
  domain?: string,
  targetServer?: string
}
```

**Response**:
```javascript
{
  checkId: "AUTH-001",
  checkName: "Accounts Without Kerberos Pre-Auth",
  category: "Authentication",
  engine: "adsi",
  requestedEngine: "adsi",
  availableEngines: ["adsi", "powershell", "combined"],
  scriptFound: true,
  scriptPath: "C:\\ADSuite\\Authentication\\AUTH-001\\adsi.ps1",
  exitCode: 0,
  durationMs: 1234,
  stdoutLength: 5678,
  stdoutRaw: "...",
  stderrRaw: "",
  findingCount: 3,
  findings: [...],
  error: null,
  diagnosis: "SUCCESS: Script ran and returned 3 findings."
}
```

**Diagnosis Messages**:
- `SCRIPT_NOT_FOUND`: Script file doesn't exist
- `SPAWN_FAILED`: PowerShell couldn't start
- `PERMISSION_DENIED`: Execution policy or file permissions
- `EMPTY_OUTPUT_SUCCESS`: Script ran but returned nothing (not domain-joined)
- `JSON_PARSE_FAILED`: Output not in JSON format
- `NO_FINDINGS_CLEAN`: No vulnerable objects found (correct)
- `SUCCESS`: Script ran successfully

---

### 2. Domain/IP Injection

**Purpose**: Target specific domain/DC without modifying scripts

**Mechanism**: Temporary script modification

**Original Script**:
```powershell
$root = [ADSI]'LDAP://RootDSE'
$domainNC = $root.defaultNamingContext.ToString()
```

**Injected Script** (Explicit Mode):
```powershell
$root = [ADSI]'LDAP://192.168.1.10/DC=corp,DC=contoso,DC=com'
$domainNC = 'DC=corp,DC=contoso,DC=com'
```

**Implementation**:
```javascript
async function injectAndWriteTempScript(scriptPath, domain, serverIp, engine) {
  // Skip for CMD and C#
  if (engine === 'cmd' || engine === 'csharp') {
    return scriptPath;
  }

  const content = fs.readFileSync(scriptPath, 'utf8');

  // Build connection preamble
  let preamble = '';
  if (serverIp && domain) {
    const dn = fqdnToDN(domain);
    preamble = `$root = [ADSI]'LDAP://${serverIp}/${dn}'\n$domainNC = '${dn}'\n`;
  } else if (serverIp) {
    preamble = `$root = [ADSI]'LDAP://${serverIp}/RootDSE'\n$domainNC = $root.defaultNamingContext.ToString()\n`;
  } else if (domain) {
    const dn = fqdnToDN(domain);
    preamble = `$root = [ADSI]'LDAP://${dn}'\n$domainNC = '${dn}'\n`;
  }

  if (!preamble) return scriptPath;

  // Replace RootDSE line
  const modifiedContent = content.replace(
    /\$root\s*=\s*\[ADSI\]['"]LDAP:\/\/RootDSE['"]\s*\n\s*\$domainNC\s*=\s*\$root\.defaultNamingContext\.ToString\(\)/g,
    preamble.trim()
  );

  // Write to temp file
  const tmpPath = path.join(os.tmpdir(), `adsuite_${uuidv4()}.ps1`);
  fs.writeFileSync(tmpPath, modifiedContent, 'utf8');
  return tmpPath;
}
```

**Cleanup**:
```javascript
proc.on('close', (code) => {
  // Clean up temp file
  if (execScriptPath !== scriptPath) {
    try { fs.unlinkSync(execScriptPath); } catch { }
  }
});
```

---

### 3. BloodHound Export

**Purpose**: Generate BloodHound-compatible JSON for graph visualization

**Environment Variables**:
```javascript
process.env.ADSUITE_SESSION_ID = scanId;
process.env.ADSUITE_OUTPUT_ROOT = REPORTS_DIR;
```

**Export Directory**:
```javascript
const bloodhoundDir = path.join(REPORTS_DIR, scanId, 'bloodhound');
fs.mkdirSync(bloodhoundDir, { recursive: true });
```

**Scripts Use These Variables**:
```powershell
$sessionId = $env:ADSUITE_SESSION_ID
$outputRoot = $env:ADSUITE_OUTPUT_ROOT
$bloodhoundPath = Join-Path $outputRoot "$sessionId\bloodhound\nodes.json"

# Export findings as BloodHound nodes
$findings | ConvertTo-Json -Depth 10 | Out-File $bloodhoundPath
```

**BloodHound Integration**:
- Findings exported as nodes with properties
- Relationships exported as edges
- Compatible with BloodHound UI
- Accessible via `/api/bloodhound/scan/:scanId`

---

### 4. Export Functionality

**Supported Formats**:
- JSON (complete findings with metadata)
- CSV (tabular format for Excel)
- PDF (formatted report with summary)

**Export Handler**:
```javascript
const handleExport = async (format) => {
  if (!activeScanId) return;

  const response = await fetch('/api/reports/export', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ scanId: activeScanId, format })
  });

  const blob = await response.blob();
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `ad-suite-scan-${activeScanId}.${format}`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  window.URL.revokeObjectURL(url);
};
```

**Export Files Location**:
```
backend/reports/{scanId}/
├── findings.json          # Complete findings
├── findings.csv           # CSV export
├── report.pdf             # PDF report
├── bloodhound/            # BloodHound data
│   ├── nodes.json
│   └── edges.json
└── per_check/             # Raw check outputs
    ├── AUTH-001_raw.json
    ├── AUTH-002_raw.json
    └── ...
```

---

### 5. Scan Abort

**Frontend**:
```javascript
const handleAbortScan = async () => {
  try {
    await abortScan();
  } catch (error) {
    alert(`Failed to abort scan: ${error.message}`);
  }
};

const abortScan = useCallback(async () => {
  if (store.activeScanId) {
    await fetch(`/api/scan/abort/${store.activeScanId}`, { method: 'POST' });
  }
  if (sseRef.current) sseRef.current.close();
  store.setScanStatus('aborted');
}, [store]);
```

**Backend**:
```javascript
router.post('/abort/:scanId', (req, res) => {
  const { scanId } = req.params;

  executor.abortActiveScan();
  db.updateScanStatus(scanId, 'aborted');

  res.json({ aborted: true });
});

function abortActiveScan() {
  if (_activeScanProcess) {
    _activeScanProcess.kill('SIGTERM');
    _activeScanProcess = null;
    _activeScanId = null;
  }
}
```

**Graceful Shutdown**:
- Kills current PowerShell process
- Clears active scan ID
- Updates database status
- Closes SSE connection
- Partial results are saved

---

### 6. Scan Resume After Refresh

**Problem**: User refreshes page during scan

**Solution**: Reconnect to existing scan

**Implementation**:
```javascript
useEffect(() => {
  if (store.activeScanId && store.scanStatus === 'running') {
    connectSSE(store.activeScanId);
  }
}, [store.activeScanId, store.scanStatus, connectSSE]);
```

**How It Works**:
1. Scan state persisted in localStorage (Zustand)
2. On page load, check if `activeScanId` exists
3. If status is 'running', reconnect SSE
4. Backend sends current progress
5. Continue receiving updates

---

### 7. PowerShell Terminal Drawer

**Component**: `PsTerminalDrawer`

**Purpose**: Interactive PowerShell terminal for manual AD queries

**Features**:
- WebSocket-based real-time communication
- Command history
- Auto-completion
- Domain/IP context awareness
- Persistent across page navigation

**Integration**:
```jsx
<PsTerminalDrawer domain={domain} serverIp={serverIp} />
```

**Use Cases**:
- Manual LDAP queries
- Test AD connectivity
- Explore domain structure
- Debug script issues
- Run custom PowerShell commands

---

## Performance Considerations

### 1. Large Finding Sets

**Problem**: Thousands of findings can slow UI

**Solutions**:
- IndexedDB for storage (not localStorage)
- Virtualized table rendering
- Pagination (1000 findings per page)
- Lazy loading of details

### 2. Long-Running Scans

**Problem**: Scans can take 30+ minutes

**Solutions**:
- SSE reconnection with exponential backoff
- State persistence (survives refresh)
- Abort functionality
- Progress indicators

### 3. Memory Management

**Problem**: Terminal logs accumulate

**Solutions**:
- Limit log lines (last 1000)
- Clear on new scan
- Collapsible terminal in complete state

---

## Security Considerations

### 1. Script Injection Prevention

**Risk**: Malicious domain/IP values could inject code

**Mitigation**:
- Validation of domain format (FQDN regex)
- Validation of IP format (IPv4/IPv6 regex)
- Temp file approach (no eval)
- Regex-based replacement (not string interpolation)

### 2. Process Isolation

**Risk**: Spawned processes could escape

**Mitigation**:
- `shell: false` (no shell interpretation)
- Timeout limits (120 seconds)
- Process tracking (kill on abort)
- Temp file cleanup

### 3. Path Traversal

**Risk**: Suite root could access arbitrary files

**Mitigation**:
- Path validation
- Existence checks
- No user-controlled script execution
- Sandboxed temp directory

---

## Troubleshooting Guide

### Issue: "Suite root path is required"

**Cause**: Empty suite root field

**Solution**: Enter path to AD-Suite-scripts-main folder

**Example**: `C:\ADSuite\AD-Suite-scripts-main`

---

### Issue: "No checks found in the specified path"

**Cause**: Invalid suite root path

**Solutions**:
1. Verify path exists
2. Check folder structure (should contain category folders)
3. Ensure scripts are extracted (not in ZIP)
4. Use absolute path

---

### Issue: "A scan is already running"

**Cause**: Concurrent scan attempt

**Solutions**:
1. Wait for current scan to complete
2. Abort current scan
3. Refresh page if scan is stuck

---

### Issue: "Domain/IP targeting is not supported for CMD engine"

**Cause**: CMD scripts don't support LDAP targeting

**Solution**: Switch to ADSI, PowerShell, or Combined engine

---

### Issue: Scan completes with 0 findings

**Possible Causes**:
1. ✓ No vulnerable objects (good!)
2. ✗ Machine not domain-joined
3. ✗ Wrong suite root path
4. ✗ Insufficient permissions

**Diagnosis**: Use Scan Diagnostics panel to test single check

---

## Summary

The Run Scans page is a comprehensive interface for executing AD security checks with:

- **Flexible Configuration**: 5 engines, 4 connection modes, 833 checks
- **Real-Time Feedback**: SSE-based progress and terminal output
- **Robust Error Handling**: Validation, diagnostics, graceful failures
- **State Persistence**: Survives page refresh, reconnects to running scans
- **Export Capabilities**: JSON, CSV, PDF, BloodHound
- **Advanced Features**: Domain targeting, diagnostics, interactive terminal

The architecture separates concerns effectively:
- Frontend handles UI and state management
- Backend handles script execution and database
- SSE provides real-time communication
- Zustand + IndexedDB provide persistent state

This design enables reliable, scalable AD security scanning with excellent UX.

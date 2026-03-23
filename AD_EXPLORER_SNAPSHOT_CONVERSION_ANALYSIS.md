# AD Explorer Snapshot to Graph Conversion - Deep Technical Analysis

## Overview
The AD Explorer Snapshot Converter is a sophisticated feature that transforms Sysinternals ADExplorer binary snapshot files (.dat) into BloodHound-compatible JSON format and interactive graph visualizations. This enables security analysts to visualize Active Directory structures without requiring live domain access.

---

## Architecture Components

### 1. Backend Route Handler (`adexplorer.js`)
**Location**: `ad-suite-web/backend/routes/adexplorer.js`

**Key Features**:
- Session-based conversion tracking with UUID identifiers
- Server-Sent Events (SSE) for real-time progress streaming
- Dual-track conversion support (convertsnapshot.exe or pure PowerShell)
- File management for converted outputs

**API Endpoints**:

#### POST `/api/integrations/adexplorer/convert`
- **Purpose**: Initiates snapshot conversion
- **Input**: `{ snapshotPath: string, convertExePath?: string }`
- **Process**:
  1. Validates snapshot file existence
  2. Creates unique session ID and output directory
  3. Spawns PowerShell process with Parse-ADExplorerSnapshot.ps1
  4. Streams stdout/stderr to session state
  5. Broadcasts progress via SSE
- **Output**: `{ sessionId: string }`

#### GET `/api/integrations/adexplorer/stream/:sessionId`
- **Purpose**: SSE endpoint for real-time conversion progress
- **Features**:
  - Replays existing log lines for reconnecting clients
  - Streams live stdout/stderr from PowerShell process
  - Sends completion event with summary and file list
  - Auto-closes on process completion or error

#### GET `/api/integrations/adexplorer/graph/:sessionId`
- **Purpose**: Serves the unified graph.json for visualization
- **Output**: JSON stream of graph data

#### GET `/api/integrations/adexplorer/files/:sessionId`
- **Purpose**: Lists all generated JSON files in session directory
- **Output**: `{ files: string[], outputDir: string }`

#### GET `/api/integrations/adexplorer/download/:sessionId/:filename`
- **Purpose**: Downloads individual converted files
- **Security**: Path traversal protection via `path.basename()`

---

### 2. PowerShell Parser (`Parse-ADExplorerSnapshot.ps1`)
**Location**: `ad-suite-web/backend/scripts/Parse-ADExplorerSnapshot.ps1`

**Requirements**: PowerShell 7.0+ (for null coalescing operators)

#### Dual-Track Conversion Strategy

**Track 1: convertsnapshot.exe (Preferred)**
- Uses pre-built Rust binary from `github.com/t94j0/adexplorersnapshot-rs`
- Outputs BloodHound-compatible tar.gz archive
- Extracts using Windows built-in `tar.exe`
- Faster and more reliable for large snapshots

**Track 2: Pure PowerShell BinaryReader (Fallback)**
- No external dependencies
- Parses binary .dat format directly
- Handles all AD object types
- Slower but universally compatible

#### Binary Format Parsing

**File Structure**:
```
[Header]
  - Magic: 0x09031122 (4 bytes)
  - Flags: DWORD
  - Server Name: null-terminated UTF-16LE string
  - Timestamp: Int64 (Windows FILETIME)
  - Mapping Offset: DWORD
  - Object Count: DWORD

[Properties Table]
  - Property Count: DWORD
  - For each property:
    - Property Index: DWORD
    - Property Type: DWORD
    - Property Name: null-terminated UTF-16LE string

[Classes Table]
  - Class Count: DWORD
  - For each class:
    - Class Index: DWORD
    - Class Name: null-terminated UTF-16LE string

[LDAP Objects]
  - For each object:
    - Attribute Count: DWORD
    - For each attribute:
      - Property Index: DWORD
      - Value Count: DWORD
      - For each value:
        - Syntax Type: DWORD
        - Value Data: (type-dependent)
```

**Supported Syntax Types**:
- `0x00080001`: DN string (UTF-16LE)
- `0x00080002`: Case-insensitive string
- `0x00080003`: Printable string
- `0x00080004`: Numeric string
- `0x00080005`: IA5 string
- `0x00080006`: UTC time string
- `0x00080007`: Generalized time string
- `0x00020001`: Integer (Int32)
- `0x00020002`: Large integer (Int64)
- `0x00010001`: Boolean
- `0x00090001`: OctetString (raw bytes, SID detection)

#### Object Classification Logic

**User Detection**:
```powershell
objectClass contains 'user' AND NOT contains 'computer'
```

**Group Detection**:
```powershell
objectClass contains 'group'
```

**Computer Detection**:
```powershell
objectClass contains 'computer'
```

**Domain Detection**:
```powershell
objectClass contains 'domain'
```

**OU Detection**:
```powershell
objectClass contains 'organizationalUnit'
```

#### BloodHound JSON Transformation

**User Object Schema**:
```json
{
  "ObjectIdentifier": "S-1-5-21-...",
  "Properties": {
    "name": "USER@DOMAIN.COM",
    "domain": "DOMAIN.COM",
    "distinguishedname": "CN=User,OU=...",
    "samaccountname": "user",
    "enabled": true,
    "admincount": false,
    "pwdlastset": 1234567890,
    "lastlogon": 1234567890,
    "pwdneverexpires": false,
    "dontreqpreauth": false,
    "passwordnotreqd": false,
    "sensitive": false,
    "unconstraineddelegation": false,
    "trustedtoauth": false,
    "hasspn": false,
    "serviceprincipalnames": [],
    "objectid": "S-1-5-21-..."
  },
  "Aces": [],
  "SPNTargets": [],
  "IsACLProtected": false,
  "ContainedBy": null
}
```

**Group Object Schema**:
```json
{
  "ObjectIdentifier": "S-1-5-21-...",
  "Properties": {
    "name": "GROUP@DOMAIN.COM",
    "domain": "DOMAIN.COM",
    "distinguishedname": "CN=Group,OU=...",
    "samaccountname": "group",
    "admincount": false,
    "description": "",
    "objectid": "S-1-5-21-..."
  },
  "Members": [
    { "ObjectIdentifier": "S-1-5-21-...", "ObjectType": "Base" }
  ],
  "Aces": [],
  "IsACLProtected": false
}
```

**Computer Object Schema**:
```json
{
  "ObjectIdentifier": "S-1-5-21-...",
  "Properties": {
    "name": "COMPUTER.DOMAIN.COM",
    "domain": "DOMAIN.COM",
    "distinguishedname": "CN=Computer,OU=...",
    "samaccountname": "computer$",
    "enabled": true,
    "unconstraineddelegation": false,
    "operatingsystem": "Windows Server 2019",
    "description": "",
    "lastlogon": 1234567890,
    "lastlogontimestamp": 1234567890,
    "objectid": "S-1-5-21-...",
    "haslaps": false
  },
  "Aces": [],
  "Sessions": [],
  "LocalAdmins": [],
  "RemoteDesktopUsers": [],
  "DcomUsers": [],
  "PSRemoteUsers": [],
  "IsACLProtected": false
}
```

#### Unified Graph.json Generation

**Purpose**: Creates a Cytoscape-compatible graph structure for visualization

**Structure**:
```json
{
  "nodes": [
    {
      "id": "S-1-5-21-...",
      "label": "user@domain",
      "type": "User",
      "properties": {
        "enabled": true,
        "admincount": false,
        "hasspn": false,
        "dn": "CN=User,OU=..."
      }
    }
  ],
  "edges": [
    {
      "source": "S-1-5-21-...",
      "target": "S-1-5-21-...",
      "type": "MemberOf",
      "label": "MemberOf"
    }
  ],
  "meta": {
    "domain": "DOMAIN.COM",
    "server": "DC01",
    "snapshotTime": 1234567890,
    "nodeCount": 1234,
    "edgeCount": 567
  }
}
```

**Edge Generation**:
- Parses `member` attribute from groups
- Resolves member DNs to SIDs via allObjects lookup
- Creates `MemberOf` edges from member → group

---

### 3. Frontend UI Component (`AdExplorerSection.jsx`)
**Location**: `ad-suite-web/frontend/src/components/AdExplorerSection.jsx`

**Features**:
- File path input with browse button (Electron file picker)
- Optional convertsnapshot.exe path configuration
- Real-time progress log with auto-scroll
- Output file listing with actions:
  - Download individual files
  - Push to BloodHound (for users/groups/computers JSON)
  - Open in Graph Visualiser (for graph.json)

**State Management**:
```javascript
{
  snapshotPath: string,
  convertExePath: string,
  sessionId: string | null,
  status: 'idle' | 'running' | 'complete' | 'error',
  logLines: Array<{ type: 'out' | 'err', text: string }>,
  outputFiles: string[],
  graphAvailable: boolean,
  summaryText: string
}
```

**SSE Connection Flow**:
1. POST `/convert` → receive sessionId
2. Open EventSource to `/stream/:sessionId`
3. Listen for events:
   - `log`: Append to logLines array
   - `complete`: Update status, files, summary
   - `error`: Display error message
4. Auto-close SSE on completion

**UI Components**:
- **Configuration Panel**: Snapshot path + optional convertsnapshot.exe path
- **Progress Log**: Scrollable terminal-style output (max 500 lines ring buffer)
- **Output Files Panel**: File list with action buttons
- **Status Badge**: Visual indicator (running/complete/error)

---

### 4. Graph Visualizer (`AdGraphVisualiser.jsx`)
**Location**: `ad-suite-web/frontend/src/components/AdGraphVisualiser.jsx`

**Technology**: Cytoscape.js for graph rendering

#### Node Styling

**Colors** (BloodHound-inspired):
```javascript
{
  User: '#5b7fa6',       // warm blue-grey
  Group: '#4e8c5f',      // warm forest green
  Computer: '#c47b3a',   // warm burnt orange
  Domain: '#8b6db5',     // warm muted purple
  OU: '#3d8c7a',         // warm teal
  GPO: '#9b59b6',        // purple
  Category: '#d4a96a',   // amber
  Finding: '#c0392b',    // warm red
  ATTACKER: '#e74c3c'    // bright red
}
```

**Shapes**:
- User: Ellipse
- Computer: Rectangle
- Group: Hexagon
- Domain: Star
- OU: Triangle
- GPO: Diamond

**Border Highlighting**:
- CRITICAL severity: Red border (#e74c3c)
- HIGH severity: Orange border (#f39c12)
- ACL Protected / adminCount: Amber border (#d4a96a)
- Default: Type color with 40% opacity

**Size Scaling**:
- Domain: 60x60px
- Computer: 35x35px
- Group: 30x30px
- User: 25x25px (default)

#### Edge Styling

**Types**:
- Attack Path: Red (#e74c3c), dashed, 3px width
- Membership: Blue (#3498db), solid, 2px width
- Relationship: Grey (#4a403a), solid, 1.5px width

**Features**:
- Bezier curves for smooth routing
- Auto-rotating labels
- Directional arrows

#### Layout Algorithms

**Available Layouts**:
1. **Force-directed (COSE)**: Physics-based, ideal edge length 100px
2. **Circle**: Nodes arranged in a circle
3. **Grid**: Rectangular grid layout
4. **Breadth-first**: Hierarchical tree layout
5. **Concentric**: Nodes in concentric circles

#### Data Source Integration

**Supported Sources**:
1. **BloodHound Export**: From scan results with BloodHound export enabled
2. **Scan Findings**: Generated from security check findings
3. **ADExplorer Session**: Direct integration with snapshot converter
4. **Demo Data**: Sample visualization for testing

**ADExplorer Integration**:
- Receives `preloadSessionId` prop from AdExplorerSection
- Auto-loads graph via `/api/integrations/adexplorer/graph/:sessionId`
- Handles both BloodHound format and legacy format

#### Properties Panel

**Displayed Information**:
- Node type badge (color-coded)
- Node label (truncated to 20 chars)
- Security findings (if present):
  - Check ID
  - Severity (color-coded)
  - MITRE ATT&CK technique
- Core AD properties:
  - SAM Account Name
  - Domain
  - Enabled status
  - ACL Protected status
  - Distinguished Name
- All other properties (key-value pairs)

#### Interactive Features

**User Actions**:
- Click node → Show properties panel
- Click background → Deselect node
- Filter by node type (dropdown)
- Change layout algorithm (dropdown)
- Fit graph to viewport
- Export as PNG (2x scale, dark background)

**Node Filtering**:
- Dynamically builds filter list from available node types
- Filters both nodes and edges (removes orphaned edges)

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERACTION                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    AdExplorerSection.jsx                         │
│  • File path input (snapshot.dat)                               │
│  • Optional convertsnapshot.exe path                            │
│  • Convert button                                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ POST /api/integrations/adexplorer/convert
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Backend: adexplorer.js                        │
│  • Validate snapshot file                                       │
│  • Create session ID + output directory                         │
│  • Spawn PowerShell process                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ spawn powershell.exe
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              Parse-ADExplorerSnapshot.ps1                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ TRACK 1: convertsnapshot.exe (if provided)              │  │
│  │  • Execute Rust binary                                   │  │
│  │  • Extract tar.gz                                        │  │
│  │  • Build graph.json from extracted files                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ TRACK 2: Pure PowerShell BinaryReader                   │  │
│  │  1. Read header (magic, server, timestamp, counts)      │  │
│  │  2. Parse properties table (attribute definitions)      │  │
│  │  3. Parse classes table (object class names)            │  │
│  │  4. Parse LDAP objects:                                 │  │
│  │     • Read attributes with syntax-specific parsing      │  │
│  │     • Classify by objectClass                           │  │
│  │     • Extract SIDs, DNs, UAC flags                      │  │
│  │  5. Transform to BloodHound JSON v4:                    │  │
│  │     • Convert-ToBloodHoundUser                          │  │
│  │     • Convert-ToBloodHoundGroup                         │  │
│  │     • Convert-ToBloodHoundComputer                      │  │
│  │     • Convert-ToBloodHoundDomain                        │  │
│  │  6. Write individual JSON files:                        │  │
│  │     • DOMAIN_users.json                                 │  │
│  │     • DOMAIN_groups.json                                │  │
│  │     • DOMAIN_computers.json                             │  │
│  │     • DOMAIN_domains.json                               │  │
│  │  7. Build unified graph.json:                           │  │
│  │     • Create nodes from all objects                     │  │
│  │     • Create MemberOf edges from group members          │  │
│  │     • Add metadata (domain, server, counts)             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  • Write-Progress-Message → stdout                              │
│  • Write-Output "SUMMARY:..." → stdout                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ stdout/stderr streams
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Backend: adexplorer.js                        │
│  • Capture stdout → session.lines + SSE broadcast               │
│  • Capture stderr → session.lines + SSE broadcast               │
│  • On close:                                                    │
│    - Parse SUMMARY line                                         │
│    - List output files                                          │
│    - Update session status                                      │
│    - Broadcast complete event                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ SSE: GET /api/integrations/adexplorer/stream/:sessionId
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    AdExplorerSection.jsx                         │
│  • Display real-time log lines                                  │
│  • Show completion status                                       │
│  • List output files with actions:                              │
│    - Download                                                   │
│    - Push to BloodHound                                         │
│    - Open in Graph Visualiser                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ onOpenInGraph(sessionId)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   AdGraphVisualiser.jsx                          │
│  • Set dataSource = 'adexplorer'                                │
│  • Set sessionId                                                │
│  • Load graph via GET /api/integrations/adexplorer/graph/:id    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ GET /api/integrations/adexplorer/graph/:sessionId
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Backend: adexplorer.js                        │
│  • Stream graph.json file                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ JSON response
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   AdGraphVisualiser.jsx                          │
│  • Parse graph data                                             │
│  • Build Cytoscape elements:                                    │
│    - Nodes with type-specific styling                           │
│    - Edges with relationship types                              │
│  • Initialize Cytoscape instance                                │
│  • Apply force-directed layout                                  │
│  • Enable interactions:                                         │
│    - Click node → show properties                               │
│    - Filter by type                                             │
│    - Change layout                                              │
│    - Export PNG                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Technical Decisions

### 1. Dual-Track Conversion Strategy
**Rationale**: Provides flexibility and reliability
- Track 1 (convertsnapshot.exe): Fast, battle-tested, handles edge cases
- Track 2 (PowerShell): No dependencies, works everywhere, easier to debug

### 2. Session-Based Architecture
**Benefits**:
- Multiple concurrent conversions
- Persistent state for reconnecting clients
- Clean separation of concerns
- Easy cleanup of old sessions

### 3. Server-Sent Events (SSE) for Progress
**Why not WebSocket?**:
- Unidirectional communication (server → client)
- Simpler protocol, less overhead
- Auto-reconnection built into EventSource
- HTTP/2 multiplexing support

### 4. Unified graph.json Format
**Purpose**: Bridge between BloodHound data and Cytoscape visualization
- Simplified node/edge structure
- Metadata for context
- Compatible with multiple data sources
- Optimized for frontend rendering

### 5. BinaryReader Parsing
**Advantages**:
- Direct binary format parsing
- No intermediate files
- Full control over data extraction
- Handles malformed data gracefully

### 6. BloodHound v4 Compatibility
**Ensures**:
- Interoperability with BloodHound CE
- Standard schema for security tools
- Future-proof data format
- Community tool compatibility

---

## Security Considerations

### 1. Path Traversal Protection
```javascript
const safe = path.basename(filename);  // Strips directory components
const filePath = path.join(session.outputDir, safe);
```

### 2. File Validation
- Checks snapshot file existence before processing
- Validates magic number in binary header
- Handles malformed data gracefully

### 3. Process Isolation
- PowerShell runs with `-ExecutionPolicy Bypass` (required for script execution)
- `-NonInteractive` flag prevents user prompts
- Timeout protection (process can be killed if needed)

### 4. Session Cleanup
- Sessions stored in memory (Map)
- Output files in isolated directories
- Manual cleanup required (consider TTL implementation)

### 5. SID Parsing
- Uses .NET SecurityIdentifier for safe SID conversion
- Handles invalid SIDs gracefully
- Base64 fallback for unknown binary data

---

## Performance Characteristics

### Snapshot Size vs. Processing Time
- **Small (< 10 MB)**: 5-15 seconds
- **Medium (10-100 MB)**: 30-120 seconds
- **Large (> 100 MB)**: 2-10 minutes

### Bottlenecks
1. **Binary parsing**: CPU-intensive (string decoding, type conversion)
2. **JSON serialization**: Memory-intensive for large object counts
3. **Graph generation**: O(n²) for member resolution

### Optimization Opportunities
1. Streaming JSON output (avoid loading entire dataset in memory)
2. Parallel object processing (PowerShell runspaces)
3. Incremental graph building (avoid full allObjects scan)
4. Caching property/class lookups

---

## Error Handling

### PowerShell Script
- `Set-StrictMode -Off`: Allows null property access
- `$ErrorActionPreference = 'Stop'`: Fails fast on critical errors
- Try-catch blocks for object parsing
- Graceful degradation for unknown syntax types

### Backend
- HTTP 400 for invalid input
- HTTP 404 for missing sessions/files
- Process error events captured and broadcast via SSE
- Non-zero exit codes trigger error status

### Frontend
- Connection loss detection (SSE onerror)
- User-friendly error messages
- Retry capability (re-run conversion)
- Validation before submission

---

## Integration Points

### 1. BloodHound Push
```javascript
// From AdExplorerSection.jsx
const pushRes = await fetch('/api/integrations/bloodhound/push', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ data }),
});
```

### 2. Graph Visualizer
```javascript
// From AdExplorerSection.jsx
<button onClick={() => onOpenInGraph(sessionId)}>
  Open in Graph Visualiser
</button>

// From AdGraphVisualiser.jsx
useEffect(() => {
  if (preloadSessionId) {
    setDataSource('adexplorer');
    setSessionId(preloadSessionId);
    loadGraph('adexplorer', preloadSessionId);
  }
}, [preloadSessionId]);
```

### 3. Scan Results
- BloodHound JSON files can be imported into scan results
- Findings can reference ADExplorer-sourced objects
- Graph visualizer supports both scan and ADExplorer data

---

## Future Enhancement Opportunities

### 1. Incremental Parsing
- Stream objects as they're parsed
- Update graph in real-time
- Reduce memory footprint

### 2. Advanced Graph Features
- Attack path calculation (shortest path algorithms)
- Privilege escalation detection
- Kerberoasting target identification
- Unconstrained delegation visualization

### 3. Snapshot Comparison
- Diff two snapshots
- Highlight changes (new users, group membership changes)
- Temporal analysis

### 4. Export Formats
- Neo4j Cypher queries
- GraphML for other tools
- CSV for spreadsheet analysis

### 5. Caching Layer
- Cache parsed snapshots
- Incremental updates
- Faster re-visualization

### 6. ACL Parsing
- Extract nTSecurityDescriptor
- Parse DACL/SACL entries
- Generate ACE edges for graph

### 7. GPO Parsing
- Extract Group Policy Objects
- Link to OUs and domains
- Visualize policy inheritance

---

## Testing Recommendations

### Unit Tests
1. Binary format parsing (various syntax types)
2. SID conversion edge cases
3. DN to FQDN extraction
4. UserAccountControl flag parsing
5. Graph edge generation

### Integration Tests
1. End-to-end conversion (small snapshot)
2. SSE event streaming
3. File download
4. Graph visualization loading

### Performance Tests
1. Large snapshot (10,000+ objects)
2. Concurrent conversions
3. Memory usage profiling
4. Graph rendering performance

### Security Tests
1. Path traversal attempts
2. Malformed snapshot files
3. Invalid session IDs
4. XSS in object properties

---

## Conclusion

The AD Explorer Snapshot to Graph Conversion feature is a robust, well-architected system that bridges the gap between offline AD snapshots and interactive security analysis. Its dual-track approach ensures reliability, while the SSE-based progress streaming provides excellent user experience. The BloodHound v4 compatibility ensures interoperability with the broader security tooling ecosystem.

**Key Strengths**:
- No live domain access required
- Real-time progress feedback
- Multiple output formats
- Interactive visualization
- BloodHound compatibility

**Production Readiness**:
- ✅ Error handling
- ✅ Security considerations
- ✅ User experience
- ⚠️ Session cleanup (manual)
- ⚠️ Performance optimization (large snapshots)

**Recommended Next Steps**:
1. Implement automatic session cleanup (TTL-based)
2. Add progress percentage calculation
3. Optimize large snapshot handling
4. Add ACL parsing for complete BloodHound parity
5. Implement snapshot comparison feature

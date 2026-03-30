## 5. Technical Implementation

### 5.1 Frontend Architecture

#### Component Structure
```
src/
├── components/
│   ├── Layout.tsx              # Main layout wrapper
│   └── GraphVisualizer.tsx     # Sigma.js graph component
├── pages/
│   ├── Dashboard.tsx           # Main dashboard
│   ├── NewScan.tsx            # Scan configuration
│   ├── Scans.tsx              # Scan history
│   ├── Terminal.tsx           # PowerShell terminal
│   ├── Reports.tsx            # Report viewer
│   ├── Analysis.tsx           # Finding analysis
│   └── Settings.tsx           # Application settings
├── store/
│   ├── useAppStore.ts         # Global state (Zustand)
│   ├── authStore.ts           # Authentication state
│   └── useFindingsStore.ts    # Findings data
├── lib/
│   └── api.ts                 # API client (Axios)
└── contexts/
    └── SettingsContext.tsx    # Settings provider
```

#### State Management Strategy
1. **Zustand** - Global application state
2. **React Query** - Server state and caching
3. **Context API** - Settings and configuration
4. **Local State** - Component-specific state

#### API Integration
```typescript
// Example API call with React Query
const { data: stats } = useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: async () => {
        const response = await api.get('/dashboard/stats');
        return response.data;
    }
});
```

### 5.2 Backend Architecture

#### API Routes
```
/api/auth
  POST   /login              # User authentication
  POST   /register           # User registration
  GET    /me                 # Current user info

/api/dashboard
  GET    /stats              # Dashboard statistics
  GET    /recent             # Recent scans

/api/scans
  GET    /                   # List all scans
  POST   /                   # Create new scan
  GET    /:id                # Get scan details
  POST   /:id/execute        # Execute scan
  DELETE /:id                # Delete scan

/api/checks
  GET    /                   # List all checks
  GET    /:id                # Get check details

/api/reports
  GET    /scans              # Available scan reports
  GET    /export/:id/:format # Export report

/terminal (WebSocket)
  - Real-time terminal communication
  - PowerShell session management
```

#### Middleware Stack
1. **CORS** - Cross-origin resource sharing
2. **Body Parser** - JSON request parsing
3. **Authentication** - JWT verification
4. **Error Handler** - Centralized error handling
5. **Logger** - Request/response logging

#### WebSocket Implementation
```typescript
// Terminal WebSocket handler
export function setupTerminalSession(ws: WebSocket) {
    const ptyProcess = pty.spawn('powershell.exe', args);
    
    ptyProcess.onData((data) => {
        // Filter ANSI sequences and null bytes
        const cleanData = data
            .replace(/\0/g, '')           // Remove null bytes
            .replace(/\x1b\[1C/g, '');    // Remove cursor forward
        
        ws.send(JSON.stringify({ 
            type: 'output', 
            data: cleanData 
        }));
    });
}
```

### 5.3 Database Schema

#### Core Tables

**users**
- id (UUID, PK)
- username (VARCHAR, UNIQUE)
- email (VARCHAR, UNIQUE)
- password_hash (VARCHAR)
- role (ENUM: admin, analyst, viewer)
- created_at (TIMESTAMP)

**scans**
- id (UUID, PK)
- name (VARCHAR)
- user_id (UUID, FK)
- status (ENUM: pending, running, completed, failed)
- started_at (TIMESTAMP)
- completed_at (TIMESTAMP)
- total_checks (INTEGER)
- total_findings (INTEGER)

**findings**
- id (UUID, PK)
- scan_id (UUID, FK)
- check_id (VARCHAR)
- severity (ENUM: critical, high, medium, low, info)
- category (VARCHAR)
- finding_count (INTEGER)
- details (JSONB)

**checks**
- id (VARCHAR, PK)
- name (VARCHAR)
- category (VARCHAR)
- severity (VARCHAR)
- description (TEXT)
- remediation (TEXT)
- engine (VARCHAR)

### 5.4 PowerShell Scan Engine

#### Module Structure
```powershell
# ADSuite.Adsi.psm1
function Invoke-ADSuiteCheck {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Check,
        
        [string]$SearchBase,
        [string]$Server
    )
    
    # Execute LDAP query
    $results = Get-ADObject -LDAPFilter $Check.ldapFilter `
                            -SearchBase $SearchBase `
                            -Server $Server
    
    # Return findings
    return @{
        CheckId = $Check.id
        FindingCount = $results.Count
        Details = $results
    }
}
```

#### Execution Flow
1. Load check catalog (checks.json)
2. Apply overrides (checks.overrides.json)
3. Filter by category/check IDs
4. Execute checks sequentially
5. Aggregate results
6. Generate HTML report
7. Save JSON output

#### Check Catalog Structure
```json
{
    "checks": [
        {
            "id": "ACC-001",
            "name": "Unconstrained Delegation",
            "category": "Access_Control",
            "severity": "high",
            "engine": "ldap",
            "ldapFilter": "(&(objectClass=computer)(userAccountControl:1.2.840.113556.1.4.803:=524288))",
            "searchBase": "DC=domain,DC=local",
            "description": "Identifies computers with unconstrained delegation",
            "remediation": "Disable unconstrained delegation"
        }
    ]
}
```

---

## 6. Security Assessment Capabilities

### 6.1 Vulnerability Detection

#### Access Control Vulnerabilities
- Unconstrained delegation
- Weak ACLs on sensitive objects
- Excessive permissions
- Orphaned SIDs
- Dangerous group memberships

#### Kerberos Vulnerabilities
- Kerberoastable accounts
- AS-REP roastable users
- Weak encryption types
- SPN misconfigurations
- Delegation issues

#### Certificate Services Vulnerabilities
- ESC1-ESC8 vulnerabilities
- Weak certificate templates
- Dangerous EKUs
- CA misconfigurations
- Certificate enrollment issues

#### Authentication Vulnerabilities
- Weak password policies
- Accounts with non-expiring passwords
- Pre-Windows 2000 compatibility
- LM hash storage
- Reversible encryption

### 6.2 Risk Scoring

#### Calculation Formula
```
Risk Score = (Σ(Severity Weight × Finding Count) / 10) / 5 × 100
```

#### Risk Bands
- **0-30**: Low Risk (Green)
- **31-60**: Moderate Risk (Yellow)
- **61-80**: High Risk (Orange)
- **81-100**: Critical Risk (Red)

#### Example Calculation
```
Critical findings: 45 × 5 = 225
High findings: 123 × 4 = 492
Medium findings: 89 × 3 = 267
Low findings: 34 × 2 = 68
Info findings: 12 × 1 = 12

Total weighted score: 1064
Capped score: min(1064, 10×5) = 50
Normalized: 50 / 5 = 10
Risk score: 10 × 100 / 10 = 100 (Critical)
```

### 6.3 Reporting

#### Report Formats
1. **HTML** - Interactive web report
2. **JSON** - Machine-readable format
3. **CSV** - Spreadsheet export
4. **PDF** - Printable document (future)

#### Report Sections
1. Executive Summary
2. Risk Score and Metrics
3. Findings by Severity
4. Findings by Category
5. Detailed Check Results
6. Remediation Guidance
7. Compliance Mapping

---

## 7. Web Application Features

### 7.1 User Interface

#### Design System
- **Color Scheme**: Orange (#E8500A) on Dark (#1A1A1A)
- **Typography**: Montserrat/Inter for headings, Inter/Open Sans for body
- **Font Sizes**: 28pt, 20pt, 14pt (headings), 10pt (body)
- **Components**: Tailwind CSS utility classes
- **Icons**: Lucide React icon library

#### Responsive Design
- **Mobile** (< 768px): Single column, stacked layout
- **Tablet** (768px - 1024px): 2-column grid
- **Desktop** (> 1024px): Full multi-column layout

#### Accessibility
- ARIA labels on interactive elements
- Keyboard navigation support
- High contrast color scheme
- Screen reader compatible
- Focus indicators

### 7.2 Dashboard Features

#### Real-time Updates
- Auto-refresh every 30 seconds
- WebSocket notifications for scan completion
- Live progress tracking
- Dynamic chart updates

#### Interactive Charts
- Hover tooltips with exact values
- Click-to-filter functionality
- Animated transitions
- Responsive sizing

#### Quick Actions
- One-click scan initiation
- Category-specific scans
- Report access
- Settings configuration

### 7.3 Scan Configuration

#### Scan Options
1. **Scan Name** - Custom identifier
2. **Category Selection** - Multi-select checkboxes
3. **Check Selection** - Individual check picker
4. **Search & Filter** - Find specific checks
5. **Selection Summary** - Real-time count

#### Execution Workflow
1. Configure scan parameters
2. Click "Run Scan"
3. Real-time progress updates
4. Automatic result loading
5. Graph visualization
6. Report generation

### 7.4 Terminal Integration

#### Features
- Direct PowerShell access
- Context variable injection
- Quick command execution
- Real-time output streaming
- ANSI color support
- Copy/paste functionality

#### Context Variables
```powershell
$global:domain = "technieum.com"
$global:domainDN = "DC=technieum,DC=com"
$global:targetServer = "192.168.1.100"
```


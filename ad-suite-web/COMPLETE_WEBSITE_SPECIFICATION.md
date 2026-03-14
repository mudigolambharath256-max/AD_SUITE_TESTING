# AD Security Suite - Complete Website Specification

**Version**: 1.0.0  
**Status**: Production Ready  
**Last Updated**: March 13, 2026  
**Technology Stack**: Node.js + Express + React + SQLite + WebSocket

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Architecture](#system-architecture)
3. [Technology Stack](#technology-stack)
4. [Database Schema](#database-schema)
5. [API Endpoints](#api-endpoints)
6. [Frontend Pages](#frontend-pages)
7. [Components](#components)
8. [Features](#features)
9. [Security Considerations](#security-considerations)
10. [Deployment](#deployment)

---

## Executive Summary

The AD Security Suite is a comprehensive web-based platform for scanning, analyzing, and reporting on Active Directory security posture. It provides:

- **775+ Security Checks** across 27 categories
- **Real-time Scan Execution** with live terminal output
- **Interactive PowerShell Terminal** for AD testing
- **Multiple Execution Engines** (ADSI, PowerShell, C#, CMD, Combined)
- **Advanced Reporting** (JSON, CSV, PDF exports)
- **Integration Capabilities** (BloodHound, Neo4j, MCP)
- **Scheduled Scans** with cron expressions
- **Dashboard Analytics** with visualizations

---

## System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Frontend (React)                         │
│  - Dashboard, RunScans, Reports, Settings, Integrations    │
│  - Real-time Terminal Output, Charts, Tables               │
│  - Interactive PowerShell Terminal Drawer                  │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP/WebSocket
                     │ (Vite Dev Server: 5173)
┌────────────────────▼────────────────────────────────────────┐
│                  Backend (Express)                           │
│  - API Routes (scan, reports, settings, integrations)      │
│  - WebSocket Terminal Server                               │
│  - Scan Execution Engine (SSE streaming)                   │
│  - Database Operations (SQLite)                            │
│  - Integration Services (BloodHound, Neo4j, MCP)           │
└────────────────────┬────────────────────────────────────────┘
                     │ Port 3001
┌────────────────────▼────────────────────────────────────────┐
│              SQLite Database                                │
│  - Scans, Findings, Reports, Settings, Schedules          │
└─────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
ad-suite-web/
├── backend/
│   ├── routes/
│   │   ├── scan.js              # Scan operations
│   │   ├── reports.js           # Export & reporting
│   │   ├── settings.js          # Configuration
│   │   ├── integrations.js      # External integrations
│   │   └── schedule.js          # Scheduled scans
│   ├── services/
│   │   ├── db.js                # Database operations
│   │   ├── executor.js          # Scan execution engine
│   │   ├── terminalServer.js    # WebSocket terminal
│   │   └── bloodhound.js        # BloodHound conversion
│   ├── data/
│   │   └── ad-suite.db          # SQLite database
│   ├── reports/                 # Generated reports
│   ├── server.js                # Express server
│   └── package.json
├── frontend/
│   ├── src/
│   │   ├── pages/
│   │   │   ├── Dashboard.jsx
│   │   │   ├── RunScans.jsx
│   │   │   ├── Reports.jsx
│   │   │   ├── Settings.jsx
│   │   │   ├── Integrations.jsx
│   │   │   ├── Schedules.jsx
│   │   │   └── AttackPath.jsx
│   │   ├── components/
│   │   │   ├── Terminal.jsx
│   │   │   ├── PsTerminalDrawer.jsx
│   │   │   ├── CheckSelector.jsx
│   │   │   ├── EngineSelector.jsx
│   │   │   ├── ScanProgress.jsx
│   │   │   ├── FindingsTable.jsx
│   │   │   ├── Sidebar.jsx
│   │   │   └── [other components]
│   │   ├── hooks/
│   │   │   ├── useScan.js
│   │   │   └── useTerminal.js
│   │   ├── store/
│   │   │   └── index.js         # Zustand store
│   │   ├── lib/
│   │   │   ├── api.js
│   │   │   └── colours.js
│   │   ├── App.jsx
│   │   └── main.jsx
│   ├── vite.config.js
│   └── package.json
└── README.md
```

---

## Technology Stack

### Backend

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Runtime | Node.js | 16+ | JavaScript runtime |
| Framework | Express | 4.18.2 | Web server framework |
| Database | SQLite | 3.x | Lightweight database |
| Driver | better-sqlite3 | 9.2.2 | Synchronous SQLite driver |
| WebSocket | ws | 8.16.0 | Real-time terminal communication |
| Scheduling | node-cron | 3.0.3 | Cron-based task scheduling |
| Export | csv-stringify | 6.6.0 | CSV generation |
| Export | pdfkit | 0.14.0 | PDF generation |
| HTTP Client | axios | 1.6.7 | API requests |
| Security | helmet | 7.1.0 | HTTP headers security |
| CORS | cors | 2.8.5 | Cross-origin requests |
| Graph DB | neo4j-driver | 5.20.0 | Neo4j integration |
| Utilities | uuid | 9.0.1 | Unique ID generation |

### Frontend

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Framework | React | 18.2.0 | UI library |
| Build Tool | Vite | 5.4.21 | Fast build tool |
| Routing | React Router | 6.22.3 | Client-side routing |
| State | Zustand | 5.0.11 | State management |
| Terminal | xterm.js | 5.3.0 | Terminal emulator |
| Terminal Fit | @xterm/addon-fit | 0.8.0 | Terminal sizing |
| Terminal Links | @xterm/addon-web-links | 0.9.0 | Clickable URLs |
| Tables | @tanstack/react-table | 8.17.3 | Data tables |
| Charts | recharts | 2.12.7 | Data visualization |
| Icons | lucide-react | 0.363.0 | Icon library |
| Markdown | react-markdown | 9.0.1 | Markdown rendering |
| Flow | reactflow | 11.11.4 | Graph visualization |
| Dates | date-fns | 3.6.0 | Date utilities |
| Storage | idb-keyval | 6.2.2 | IndexedDB wrapper |
| CSS | TailwindCSS | 3.4.3 | Utility CSS framework |

---

## Database Schema

### Tables

#### 1. scans
```sql
CREATE TABLE scans (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  status TEXT,                    -- running, complete, error, aborted
  engine TEXT,                    -- adsi, powershell, csharp, cmd, combined
  domain TEXT,
  serverIp TEXT,
  suiteRoot TEXT,
  selectedChecks TEXT,            -- JSON array
  startTime DATETIME,
  endTime DATETIME,
  duration TEXT,
  totalChecks INTEGER,
  completedChecks INTEGER,
  findings INTEGER,
  criticalCount INTEGER,
  highCount INTEGER,
  mediumCount INTEGER,
  lowCount INTEGER,
  infoCount INTEGER,
  output TEXT,                    -- Terminal output
  error TEXT,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### 2. findings
```sql
CREATE TABLE findings (
  id TEXT PRIMARY KEY,
  scanId TEXT NOT NULL,
  checkId TEXT,
  checkName TEXT,
  category TEXT,
  severity TEXT,                 -- CRITICAL, HIGH, MEDIUM, LOW, INFO
  title TEXT,
  description TEXT,
  remediation TEXT,
  affectedObjects TEXT,          -- JSON array
  evidence TEXT,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (scanId) REFERENCES scans(id)
);
```

#### 3. settings
```sql
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  type TEXT,                     -- string, number, boolean, json
  updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### 4. schedules
```sql
CREATE TABLE schedules (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  cronExpression TEXT,
  engine TEXT,
  domain TEXT,
  serverIp TEXT,
  suiteRoot TEXT,
  selectedChecks TEXT,           -- JSON array
  enabled BOOLEAN DEFAULT 1,
  lastRun DATETIME,
  nextRun DATETIME,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### 5. integrations
```sql
CREATE TABLE integrations (
  id TEXT PRIMARY KEY,
  type TEXT,                     -- bloodhound, neo4j, mcp
  name TEXT,
  config TEXT,                   -- JSON
  enabled BOOLEAN DEFAULT 0,
  lastSync DATETIME,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### 6. reports
```sql
CREATE TABLE reports (
  id TEXT PRIMARY KEY,
  scanId TEXT,
  format TEXT,                   -- json, csv, pdf
  filePath TEXT,
  fileSize INTEGER,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (scanId) REFERENCES scans(id)
);
```

---

## API Endpoints

### Scan Operations (`/api/scan`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/scan/discover-checks` | Discover checks from suite root |
| POST | `/api/scan/validate-target` | Validate domain/IP connectivity |
| POST | `/api/scan/start` | Start a new scan |
| GET | `/api/scan/status/:scanId` | Get scan status |
| POST | `/api/scan/abort/:scanId` | Abort running scan |
| GET | `/api/scan/history` | Get scan history |
| GET | `/api/scan/:scanId` | Get scan details |
| DELETE | `/api/scan/:scanId` | Delete scan |
| GET | `/api/scan/:scanId/findings` | Get scan findings |

### Reports (`/api/reports`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/reports/export` | Export scan(s) to JSON/CSV/PDF |
| GET | `/api/reports/list` | List all reports |
| DELETE | `/api/reports/:reportId` | Delete report |
| GET | `/api/reports/:reportId/download` | Download report file |

### Settings (`/api/settings`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/settings/:key` | Get setting value |
| POST | `/api/settings` | Set setting value |
| GET | `/api/settings/suite-info` | Get suite information |
| POST | `/api/settings/test-powershell` | Test PowerShell availability |
| POST | `/api/settings/detect-compiler` | Detect C# compiler |
| POST | `/api/settings/db/export` | Export database |
| POST | `/api/settings/db/clear` | Clear database |
| POST | `/api/settings/db/reset` | Reset database |

### Integrations (`/api/integrations`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/integrations/list` | List integrations |
| POST | `/api/integrations/configure` | Configure integration |
| POST | `/api/integrations/test` | Test integration connection |
| POST | `/api/integrations/push` | Push findings to integration |
| DELETE | `/api/integrations/:integrationId` | Delete integration |

### Schedules (`/api/schedules`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/schedules/list` | List scheduled scans |
| POST | `/api/schedules/create` | Create schedule |
| PUT | `/api/schedules/:scheduleId` | Update schedule |
| DELETE | `/api/schedules/:scheduleId` | Delete schedule |
| POST | `/api/schedules/:scheduleId/run` | Run scheduled scan now |

### Dashboard (`/api/dashboard`)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/dashboard/severity-summary` | Get severity breakdown |
| GET | `/api/dashboard/category-summary` | Get findings by category |

### Utilities

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/health` | Health check |
| GET | `/api/categories` | Get all categories |

### WebSocket (`/terminal`)

**Connection**: `ws://localhost:3001/terminal`

**Messages**:
- Client → Server: `input`, `init`, `resize`, `ping`
- Server → Client: `ready`, `output`, `closed`, `error`, `pong`

---

## Frontend Pages

### 1. Dashboard (`/`)

**Purpose**: Overview of security posture

**Components**:
- Severity summary (pie chart)
- Category breakdown (bar chart)
- Recent scans (table)
- Quick stats (cards)
- Top findings (list)

**Features**:
- Real-time data refresh
- Drill-down to findings
- Export summary

### 2. Run Scans (`/run-scans`)

**Purpose**: Execute security checks

**Sections**:
- **Left Panel (Configuration)**
  - Suite Root Path validation
  - Target Configuration (domain, server IP)
  - Connection mode indicator
  - Execution Engine selector
  - Check selector (by category)

- **Right Panel (Results)**
  - Scan status indicator
  - Live progress tracking
  - Terminal output (SSE streaming)
  - Findings table
  - Export buttons

- **Bottom Panel (PowerShell Terminal)**
  - Interactive terminal drawer
  - Quick command buttons
  - Context injection
  - Session management

**Features**:
- Real-time scan execution
- Live terminal output
- Interactive PowerShell terminal
- Concurrent scan prevention
- Scan history

### 3. Reports (`/reports`)

**Purpose**: View and manage scan reports

**Sections**:
- Scan history table
- Findings filter/search
- Bulk operations (export, delete)
- Report generation

**Features**:
- Multi-format export (JSON, CSV, PDF)
- Findings filtering by severity/category
- Bulk scan operations
- Report download
- Scan deletion

### 4. Settings (`/settings`)

**Purpose**: Configure application

**Sections**:
- Suite Root Path
- PowerShell detection
- C# compiler detection
- Database management
- Integration configuration

**Features**:
- Path validation
- Compiler detection
- Database export/clear/reset
- Integration setup

### 5. Integrations (`/integrations`)

**Purpose**: Connect external tools

**Supported Integrations**:
- BloodHound (CE & Legacy)
- Neo4j
- MCP Servers

**Features**:
- Connection testing
- Findings push
- Configuration management

### 6. Schedules (`/schedules`)

**Purpose**: Automate scan execution

**Features**:
- Cron expression builder
- Schedule creation/editing
- Manual trigger
- Execution history

### 7. Attack Path (`/attack-path`)

**Purpose**: Visualize attack chains

**Features**:
- Graph visualization (reactflow)
- Node types (finding, object, control)
- Interactive exploration
- LLM analysis integration

---

## Components

### Core Components

| Component | Purpose | Props |
|-----------|---------|-------|
| Terminal | Display scan output | lines, isRunning, height |
| PsTerminalDrawer | Interactive PowerShell terminal | domain, serverIp |
| CheckSelector | Select checks by category | selectedChecks, onSelectionChange, availableChecks |
| EngineSelector | Choose execution engine | selectedEngine, onEngineChange |
| ScanProgress | Show scan progress | scan, progress, logs |
| FindingsTable | Display findings | findings, loading, filters |
| Sidebar | Navigation | - |

### Hooks

| Hook | Purpose | Returns |
|------|---------|---------|
| useScan | Manage scan state | startScan, abortScan, scanStatus, findings |
| useTerminal | Manage terminal session | status, sendCommand, clearTerminal, reconnect |

### Store (Zustand)

**State**:
```javascript
{
  // Configuration
  suiteRoot: string,
  domain: string,
  serverIp: string,
  engine: string,
  selectedCheckIds: string[],
  availableChecks: object[],
  
  // Status
  suiteRootValid: boolean,
  isScanning: boolean,
  
  // Methods
  setSuiteRoot,
  setDomain,
  setServerIp,
  setEngine,
  setSelectedCheckIds,
  setAvailableChecks,
  setSuiteRootValid
}
```

---

## Features

### 1. Scan Execution

**Engines**:
- **ADSI**: Active Directory Service Interfaces
- **PowerShell**: PowerShell scripts
- **C#**: Compiled C# executables
- **CMD**: Batch commands
- **Combined**: Multi-engine execution

**Execution Flow**:
1. Validate suite root
2. Discover available checks
3. Spawn executor process
4. Stream output via SSE
5. Parse findings
6. Store in database
7. Generate report

### 2. Real-Time Terminal Output

**Technology**: Server-Sent Events (SSE)

**Features**:
- Live streaming
- Color-coded output
- Scrollable history
- Copy/paste support

### 3. Interactive PowerShell Terminal

**Technology**: WebSocket + xterm.js

**Features**:
- Real PowerShell process
- Context injection (domain/IP variables)
- Quick command buttons
- Session management
- 30-minute idle timeout
- Max 3 concurrent sessions

### 4. Reporting

**Formats**:
- **JSON**: Complete findings data
- **CSV**: Tabular format
- **PDF**: Formatted report

**Contents**:
- Scan metadata
- Severity breakdown
- Findings details
- Remediation guidance

### 5. Integrations

**BloodHound**:
- Convert findings to BloodHound format
- Push to BloodHound instance
- Visualize attack paths

**Neo4j**:
- Store findings in graph database
- Query relationships
- Analyze attack chains

**MCP**:
- Custom workflow integration
- Extensible architecture

### 6. Scheduled Scans

**Features**:
- Cron expression support
- Automatic execution
- Email notifications (optional)
- Execution history

### 7. Dashboard Analytics

**Visualizations**:
- Severity pie chart
- Category bar chart
- Trend analysis
- Top findings

---

## Security Considerations

### Authentication & Authorization

- **Current**: No authentication (local/trusted network)
- **Recommended**: 
  - Implement OAuth2/OIDC
  - Role-based access control (RBAC)
  - API key authentication

### Data Protection

- **Database**: SQLite (local file)
- **Recommendations**:
  - Encrypt sensitive data at rest
  - Use HTTPS in production
  - Implement database backups

### Input Validation

- Suite root path validation
- Domain/IP format validation
- Check ID validation
- Cron expression validation

### Process Security

- PowerShell execution policy: Bypass
- No command logging (privacy)
- Session timeout (30 minutes)
- Process cleanup on disconnect

### Network Security

- WebSocket over WSS in production
- CORS configuration
- Helmet security headers
- Rate limiting (recommended)

---

## Deployment

### Development

```bash
# Backend
cd backend
npm install
npm start

# Frontend (separate terminal)
cd frontend
npm install
npm run dev
```

**URLs**:
- Frontend: http://localhost:5173
- Backend: http://localhost:3001
- WebSocket: ws://localhost:3001/terminal

### Production

**Backend**:
```bash
npm install --production
NODE_ENV=production npm start
```

**Frontend**:
```bash
npm run build
# Serve dist/ folder via web server
```

**Environment Variables**:
```
NODE_ENV=production
PORT=3001
SUITE_ROOT=/path/to/AD-Suite
```

### Docker (Recommended)

```dockerfile
# Backend Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY backend/ .
RUN npm install --production
EXPOSE 3001
CMD ["npm", "start"]
```

```dockerfile
# Frontend Dockerfile
FROM node:18-alpine as builder
WORKDIR /app
COPY frontend/ .
RUN npm install && npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
```

### Reverse Proxy (nginx)

```nginx
upstream backend {
  server localhost:3001;
}

server {
  listen 80;
  server_name ad-suite.example.com;

  location / {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
  }

  location /terminal {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
  }
}
```

---

## Performance Considerations

### Backend

- **Database**: SQLite suitable for <100K findings
- **Concurrency**: Single scan at a time (by design)
- **Memory**: ~200MB baseline + scan overhead
- **Disk**: Database grows ~1MB per 1000 findings

### Frontend

- **Bundle Size**: ~500KB (gzipped)
- **Initial Load**: ~2-3 seconds
- **Terminal**: Handles 1000+ lines efficiently
- **Charts**: Recharts optimized for <10K data points

### Optimization Tips

1. **Database**: Add indexes on frequently queried columns
2. **Frontend**: Implement virtual scrolling for large tables
3. **Backend**: Cache check discovery results
4. **Terminal**: Limit scrollback buffer to 5000 lines

---

## Monitoring & Logging

### Recommended Monitoring

- Backend process health
- Database size growth
- Scan execution time
- API response times
- WebSocket connection count

### Logging

**Backend**:
- Server startup/shutdown
- Scan start/completion
- Errors and exceptions
- Terminal session open/close

**Frontend**:
- Console errors
- API failures
- WebSocket disconnections

---

## Future Enhancements

1. **Authentication**: OAuth2/OIDC integration
2. **Multi-tenancy**: Support multiple organizations
3. **Advanced Analytics**: Machine learning for anomaly detection
4. **Mobile App**: React Native mobile client
5. **API Documentation**: OpenAPI/Swagger
6. **Webhooks**: Event-driven integrations
7. **Audit Logging**: Complete audit trail
8. **Custom Checks**: User-defined check creation
9. **Compliance Reports**: HIPAA, PCI-DSS, SOC2
10. **Performance Optimization**: Caching, CDN, database optimization

---

## Support & Documentation

- **README.md**: Project overview
- **QUICK_START.md**: 5-minute setup guide
- **TESTING_GUIDE.md**: Test procedures
- **TERMINAL_QUICK_GUIDE.md**: Terminal usage
- **API Documentation**: Inline code comments

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-03-13 | Initial release with 775+ checks, terminal, integrations |

---

## Contact & Support

For issues, feature requests, or questions:
- Check documentation files
- Review code comments
- Consult API endpoint specifications
- Test with provided testing guide

---

**End of Specification Document**

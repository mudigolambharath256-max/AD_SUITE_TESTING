# AD Security Suite - Quick Reference Guide

## System Overview

**What It Does**: Scans Active Directory for 775+ security vulnerabilities across 27 categories

**How It Works**:
1. User configures scan (domain, server IP, checks to run)
2. Backend spawns executor process (PowerShell/ADSI/C#/CMD)
3. Executor runs checks and streams output
4. Findings are parsed and stored in database
5. Results displayed in web UI with charts and tables

---

## Quick Start (5 Minutes)

```bash
# 1. Install dependencies
cd ad-suite-web/backend && npm install
cd ../frontend && npm install

# 2. Start backend (Terminal 1)
cd backend && npm start
# Output: [Server] Express running on http://localhost:3001

# 3. Start frontend (Terminal 2)
cd frontend && npm run dev
# Output: ➜ Local: http://localhost:5173

# 4. Open browser
# Navigate to http://localhost:5173
```

---

## Key Concepts

### Execution Engines

| Engine | Use Case | Speed | Compatibility |
|--------|----------|-------|---------------|
| **ADSI** | LDAP queries | Fast | All Windows |
| **PowerShell** | Complex logic | Medium | Windows 5.1+ |
| **C#** | Performance | Very Fast | .NET 4.x+ |
| **CMD** | Simple checks | Fast | All Windows |
| **Combined** | Best coverage | Medium | All Windows |

### Check Categories (27 Total)

```
Access_Control (45 checks)
Advanced_Security (10 checks)
Authentication (33 checks)
Azure_AD_Integration (42 checks)
Backup_Recovery (8 checks)
Certificate_Services (53 checks)
Compliance (20 checks)
Computer_Management (37 checks)
Computers_Servers (30 checks)
Domain_Configuration (31 checks)
Domain_Controllers (40 checks)
Group_Policy (51 checks)
Infrastructure (33 checks)
Kerberos_Security (45 checks)
LDAP_Security (15 checks)
Network_Security (10 checks)
Persistence_Detection (12 checks)
PKI_Services (30 checks)
Privileged_Access (32 checks)
Published_Resources (30 checks)
Security_Accounts (30 checks)
Service_Accounts (31 checks)
SMB_Security (12 checks)
Trust_Management (32 checks)
Trust_Relationships (31 checks)
Users_Accounts (35 checks)
```

### Severity Levels

- **CRITICAL**: Immediate action required
- **HIGH**: Should be addressed soon
- **MEDIUM**: Plan remediation
- **LOW**: Monitor and track
- **INFO**: Informational only

---

## Frontend Pages

### Dashboard (`/`)
- **Purpose**: Security posture overview
- **Shows**: Severity breakdown, recent scans, top findings
- **Actions**: View details, drill down

### Run Scans (`/run-scans`)
- **Purpose**: Execute security checks
- **Steps**:
  1. Enter Suite Root Path (e.g., `C:\Users\acer\Downloads\AD_suiteXXX`)
  2. Click "Validate" to discover checks
  3. (Optional) Enter domain and server IP
  4. Select execution engine
  5. Select checks to run
  6. Click "Run Scan"
  7. Watch live terminal output
  8. View findings when complete

### Reports (`/reports`)
- **Purpose**: View and export scan results
- **Features**: Filter findings, export to JSON/CSV/PDF, delete scans

### Settings (`/settings`)
- **Purpose**: Configure application
- **Options**: Suite path, PowerShell test, database management

### Integrations (`/integrations`)
- **Purpose**: Connect to external tools
- **Supported**: BloodHound, Neo4j, MCP

### Schedules (`/schedules`)
- **Purpose**: Automate scans
- **Features**: Cron expressions, manual trigger

### Attack Path (`/attack-path`)
- **Purpose**: Visualize attack chains
- **Features**: Graph visualization, LLM analysis

---

## PowerShell Terminal

### How to Use

1. **Open Terminal**: Click "PS Terminal" button at bottom of Run Scans page
2. **Wait for Initialization**: ~2 seconds for PowerShell to start
3. **See Context Injection**: Domain/IP variables automatically set
4. **Run Commands**: Type manually or click quick command buttons
5. **Available Variables**:
   - `$domain` - Your domain FQDN
   - `$domainDN` - Distinguished Name
   - `$targetServer` - Server IP

### Quick Commands

- **whoami** - Current user
- **hostname** - Computer name
- **ipconfig** - Network config
- **ping [IP]** - Test connectivity
- **LDAP :389** - Test LDAP port
- **⚡ Full AD Test** - Comprehensive connectivity check

### Drawer States

- **Closed** (0px) - Button visible, no session
- **Minimized** (44px) - Header only, session alive
- **Normal** (380px) - Full terminal
- **Expanded** (620px) - More space

---

## API Endpoints (Quick Reference)

### Scan Operations
```
POST   /api/scan/discover-checks      - Find checks in suite
POST   /api/scan/validate-target      - Test domain/IP
POST   /api/scan/start                - Begin scan
GET    /api/scan/status/:scanId       - Check progress
POST   /api/scan/abort/:scanId        - Stop scan
GET    /api/scan/:scanId/findings     - Get results
```

### Reports
```
POST   /api/reports/export            - Export to JSON/CSV/PDF
GET    /api/reports/list              - List all reports
DELETE /api/reports/:reportId         - Delete report
```

### Settings
```
GET    /api/settings/:key             - Get setting
POST   /api/settings                  - Set setting
POST   /api/settings/test-powershell  - Test PS availability
```

### WebSocket
```
ws://localhost:3001/terminal          - Interactive terminal
```

---

## Database Schema (Simplified)

### scans
```
id, name, status, engine, domain, serverIp, 
startTime, endTime, findings, criticalCount, ...
```

### findings
```
id, scanId, checkId, checkName, category, 
severity, title, description, remediation, ...
```

### settings
```
key, value, type
```

### schedules
```
id, name, cronExpression, engine, enabled, lastRun, ...
```

---

## Common Tasks

### Run a Scan

1. Go to Run Scans page
2. Enter Suite Root: `C:\Users\acer\Downloads\AD_suiteXXX`
3. Click "Validate"
4. (Optional) Enter domain: `corp.domain.local`
5. (Optional) Enter server IP: `192.168.1.10`
6. Select engine: PowerShell (recommended)
7. Select checks: Click categories to expand
8. Click "Run Scan"
9. Wait for completion
10. View findings in table

### Export Results

1. Go to Reports page
2. Find scan in history
3. Click "JSON", "CSV", or "PDF" button
4. File downloads automatically

### Schedule Automatic Scans

1. Go to Schedules page
2. Click "Create Schedule"
3. Enter name: "Weekly AD Scan"
4. Enter cron: `0 2 * * 0` (Sunday 2 AM)
5. Configure scan settings
6. Click "Create"

### Test AD Connectivity

1. Go to Run Scans page
2. Enter domain and server IP
3. Click "Test Connection"
4. Or open PS Terminal and click "⚡ Full AD Test"

---

## Troubleshooting

### Terminal Won't Open
- Check backend is running on port 3001
- Check browser console for errors (F12)
- Verify WebSocket proxy in vite.config.js

### PowerShell Not Found
- Ensure powershell.exe is in PATH
- Should be default on Windows
- Check backend console for error message

### Scan Won't Start
- Validate Suite Root path first
- Select at least one check
- Ensure no other scan is running

### Findings Not Showing
- Wait for scan to complete
- Check scan status in history
- Verify checks were selected

### Database Issues
- Go to Settings page
- Click "Export Database" to backup
- Click "Clear Database" to reset
- Click "Reset Database" to reinitialize

---

## Performance Tips

### For Large Environments

1. **Use Combined Engine**: Better coverage
2. **Run During Off-Hours**: Minimize impact
3. **Schedule Scans**: Automate regular checks
4. **Export Results**: Archive for compliance
5. **Monitor Database**: Check size growth

### Optimization

- Limit scrollback in terminal (5000 lines)
- Use filters in Reports page
- Archive old scans
- Use specific check categories

---

## Security Best Practices

1. **Run on Trusted Network**: No authentication by default
2. **Restrict Access**: Use firewall/VPN
3. **Backup Database**: Regular exports
4. **Review Findings**: Act on critical issues
5. **Update Suite**: Keep checks current
6. **Secure Credentials**: Don't store in findings

---

## File Locations

```
ad-suite-web/
├── backend/
│   ├── data/ad-suite.db          ← Database
│   ├── reports/                  ← Generated reports
│   ├── terminal-sessions.log     ← Terminal log
│   └── server.js                 ← Start here
├── frontend/
│   ├── src/pages/                ← UI pages
│   ├── src/components/           ← Reusable components
│   └── vite.config.js            ← Build config
└── README.md                      ← Documentation
```

---

## Key Technologies

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Frontend | React 18 | UI framework |
| Frontend | Vite | Build tool |
| Frontend | Zustand | State management |
| Frontend | xterm.js | Terminal emulator |
| Backend | Express | Web server |
| Backend | SQLite | Database |
| Backend | WebSocket | Real-time terminal |
| Backend | Node-cron | Scheduling |

---

## Ports & URLs

| Service | URL | Port |
|---------|-----|------|
| Frontend Dev | http://localhost:5173 | 5173 |
| Backend API | http://localhost:3001 | 3001 |
| WebSocket | ws://localhost:3001/terminal | 3001 |
| Database | ./backend/data/ad-suite.db | - |

---

## Support Resources

- **README.md** - Project overview
- **QUICK_START.md** - Setup guide
- **TESTING_GUIDE.md** - Test procedures
- **TERMINAL_QUICK_GUIDE.md** - Terminal usage
- **COMPLETE_WEBSITE_SPECIFICATION.md** - Full technical spec
- **AD_Suite_Complete_Inventory.txt** - All 775+ checks

---

## Version Info

- **Version**: 1.0.0
- **Status**: Production Ready
- **Last Updated**: March 13, 2026
- **Node.js**: 16+
- **React**: 18.2.0
- **Express**: 4.18.2

---

**For detailed information, see COMPLETE_WEBSITE_SPECIFICATION.md**

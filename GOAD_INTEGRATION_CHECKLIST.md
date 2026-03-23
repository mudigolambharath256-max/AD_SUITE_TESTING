# GOAD Lab Integration Checklist

## Pre-Testing Verification

### ✅ System Requirements
- [x] Windows system with PowerShell 5.1+
- [x] Node.js installed (backend & frontend)
- [x] GOAD lab environment accessible
- [x] Network connectivity to GOAD domain controllers

### ✅ Backend Services Status
- [x] Backend server running on port 3001
- [x] Frontend dev server running on port 5173
- [x] Database initialized (SQLite)
- [x] All routes properly configured

### ✅ Core Features Implemented
1. **Scan Engine**
   - [x] ADSI engine support
   - [x] PowerShell engine support
   - [x] Domain targeting (GOAD domains)
   - [x] Server IP targeting
   - [x] Check discovery from suite root
   - [x] Real-time scan progress (SSE)

2. **Attack Path Analysis**
   - [x] LLM integration (Anthropic, OpenAI, Ollama)
   - [x] Automatic filtering (top 100 findings by severity)
   - [x] Pagination/chunking for large datasets
   - [x] Mermaid diagram generation with colors
   - [x] Interactive node clicking with findings panel
   - [x] Zoom controls
   - [x] Finding matching algorithm (improved)

3. **BloodHound Integration**
   - [x] Findings to BloodHound node conversion
   - [x] Automatic relationship generation
   - [x] Attack edge creation
   - [x] Domain node generation
   - [x] JSON export format compatible

4. **Data Management**
   - [x] SQLite database for findings storage
   - [x] Scan history tracking
   - [x] Finding severity filtering
   - [x] Category-based organization

---

## GOAD Lab Testing Steps

### 1. Configure Suite Root Path
```
Path: C:\path\to\AD-Suite-scripts-main
```
- Navigate to Settings page
- Click "Browse" to select AD Suite root folder
- Validate path shows green checkmark

### 2. Test Domain Connectivity
**GOAD Domains to Test:**
- `north.sevenkingdoms.local` (Main domain)
- `sevenkingdoms.local` (Root domain)
- `essos.local` (Child domain)

**Test Steps:**
1. Go to Scan page
2. Enter domain name (e.g., `sevenkingdoms.local`)
3. Click "Validate Target"
4. Should show: ✅ "Connection successful" with domain NC

### 3. Run Initial Scan
**Recommended First Scan:**
- Domain: `sevenkingdoms.local`
- Categories: Authentication, Users_Accounts, Access_Control
- Engine: ADSI (fastest)
- Expected findings: 50-200 depending on GOAD setup

**Monitor:**
- Real-time progress bar
- Finding count updates
- Completion notification

### 4. Test Attack Path Analysis
**With GOAD Sample Data:**
1. Load findings from completed scan
2. Configure LLM:
   - Provider: Anthropic/OpenAI
   - API Key: Your key
   - Max Findings: 100
3. Click "Analyse Attack Paths"

**Expected Results:**
- Colored Mermaid diagram showing:
  - Green: Attacker node
  - Cyan: Reconnaissance (user enumeration)
  - Orange: Exploitation (ASREPRoast, Kerberoast)
  - Red: Domain Admin access
- Interactive nodes with finding details
- Analysis metadata showing filtering

### 5. Test Finding Matching
**Click on nodes like:**
- "sansa.stark" → Should show AUTH-001 finding
- "tyrion.lannister" → Should show USR-002 finding
- "Domain Admin" → Should show USR-019 finding
- "winterfell-server" → Should show ACC-001 finding

### 6. Test Large Dataset Handling
**Simulate 1000+ findings:**
1. Run multiple scans across all categories
2. Combine findings (should have 500-1000)
3. Run LLM analysis
4. Verify:
   - Automatic filtering to top 100
   - Metadata shows "Analyzed 100 out of 1000"
   - No token limit errors
   - Graph renders successfully

### 7. Test BloodHound Export
1. Complete a scan
2. Go to Integrations page
3. Export to BloodHound format
4. Verify JSON structure:
   - Nodes array with ObjectIdentifier
   - Properties with domain, DN, samaccountname
   - Labels (User, Computer, Group, Domain)
   - Edges with source/target relationships

---

## Known GOAD-Specific Findings

### Expected High-Severity Findings:
1. **AUTH-001**: Accounts without Kerberos pre-auth
   - `sansa.stark@north.sevenkingdoms.local`
   - Vulnerable to ASREPRoasting

2. **USR-002**: Kerberoastable accounts
   - `sql_svc@sevenkingdoms.local`
   - Service accounts with SPNs

3. **USR-019**: Domain Admins
   - `eddard.stark@sevenkingdoms.local`
   - `tywin.lannister@sevenkingdoms.local`

4. **ACC-001**: Unconstrained delegation
   - `winterfell.north.sevenkingdoms.local`
   - Domain controller or server

5. **ACC-002**: Privileged groups
   - Domain Admins
   - Enterprise Admins
   - Schema Admins

### Expected Attack Paths:
```
Attacker → ASREPRoast sansa.stark → Crack hash → 
Access as sansa.stark → Kerberoast sql_svc → 
Crack SPN hash → Access SQL server → 
Exploit delegation → Domain Admin
```

---

## Troubleshooting Guide

### Issue: "No findings found"
**Causes:**
- Suite root path incorrect
- Domain not reachable
- Insufficient permissions
- LDAP port blocked

**Solutions:**
1. Verify suite root contains category folders
2. Test domain connectivity with `nltest /dsgetdc:sevenkingdoms.local`
3. Ensure running as domain user or with credentials
4. Check firewall allows LDAP (389/636)

### Issue: "LLM token limit exceeded"
**Causes:**
- Too many findings sent to LLM
- Max findings set too high (>200)

**Solutions:**
1. Reduce "Max Findings to Analyze" to 50-100
2. Use severity filter (CRITICAL + HIGH only)
3. Backend will auto-chunk if needed

### Issue: "Graph not rendering"
**Causes:**
- Mermaid syntax error
- Missing color definitions
- Browser compatibility

**Solutions:**
1. Check browser console for errors
2. Try "Open in New Window" button
3. Refresh page and re-analyze
4. Use Chrome/Edge (best compatibility)

### Issue: "Finding matching returns 0 results"
**Causes:**
- Node label doesn't match finding name
- Special characters in labels
- Case sensitivity

**Solutions:**
- Algorithm now handles:
  - Partial matches (e.g., "sansa.stark Cracked" → "sansa.stark")
  - Attack keywords (ASREPRoast, Kerberoast, etc.)
  - Multiple strategies (direct, reverse, part-by-part)

---

## Performance Benchmarks

### Scan Performance (GOAD):
- **Small scan** (5 checks): 30-60 seconds
- **Medium scan** (20 checks): 2-5 minutes
- **Full scan** (100+ checks): 10-20 minutes

### LLM Analysis Performance:
- **50 findings**: 10-20 seconds
- **100 findings**: 20-40 seconds
- **200 findings**: 40-60 seconds
- **500+ findings**: Auto-filtered to 100

### Database Performance:
- **1000 findings**: <1 second query
- **10,000 findings**: 1-2 seconds query
- **100,000 findings**: 5-10 seconds query

---

## API Endpoints for Testing

### Health Check
```bash
curl http://localhost:3001/api/health
```

### Validate Domain
```bash
curl -X POST http://localhost:3001/api/scan/validate-target \
  -H "Content-Type: application/json" \
  -d '{"domain":"sevenkingdoms.local"}'
```

### Get Recent Scans
```bash
curl http://localhost:3001/api/scan/recent?limit=10
```

### Get BloodHound Data
```bash
curl http://localhost:3001/api/bloodhound/scan/{scanId}
```

---

## Success Criteria

### ✅ Integration is successful if:
1. Can connect to GOAD domains
2. Scans complete without errors
3. Findings are stored in database
4. LLM analysis generates colored diagrams
5. Large datasets (1000+) are handled gracefully
6. Finding matching works for GOAD usernames
7. BloodHound export produces valid JSON
8. No token limit errors with automatic filtering
9. Interactive graph responds to clicks
10. Zoom controls work smoothly

---

## Post-Testing Validation

### Data Integrity Checks:
```sql
-- Check total findings
SELECT COUNT(*) FROM findings;

-- Check severity distribution
SELECT severity, COUNT(*) FROM findings GROUP BY severity;

-- Check category distribution
SELECT category, COUNT(*) FROM findings GROUP BY category;

-- Check recent scans
SELECT id, timestamp, engine, finding_count, status FROM scans ORDER BY timestamp DESC LIMIT 10;
```

### File System Checks:
- Database file exists: `ad-suite-web/backend/data/ad-suite.db`
- Reports directory: `ad-suite-web/backend/reports/`
- Scan folders created: `ad-suite-web/backend/reports/{scanId}/`

---

## Contact & Support

If you encounter issues during GOAD testing:
1. Check browser console for JavaScript errors
2. Check backend terminal for Node.js errors
3. Review `ad-suite-web/backend/logs/` if logging enabled
4. Test with sample data first before GOAD
5. Verify GOAD lab is fully operational

---

## Version Information
- Backend: Node.js + Express
- Frontend: React + Vite
- Database: SQLite3
- LLM: Anthropic Claude / OpenAI GPT / Ollama
- Graph: Mermaid.js v10
- Integration: BloodHound CE compatible

**Last Updated:** 2024
**Status:** ✅ Ready for GOAD Testing

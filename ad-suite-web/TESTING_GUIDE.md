# AD Security Suite - Testing Guide

## 🧪 Complete Testing Checklist

This guide provides step-by-step instructions for testing all functionality of the AD Security Suite.

---

## Prerequisites

### Required Software
- ✅ Node.js 16+ installed
- ✅ PowerShell available (Windows)
- ✅ AD Security Suite scripts downloaded
- ⚠️ .NET Framework 4.x (optional, for C# checks)

### Environment Setup
```bash
# 1. Install backend dependencies
cd ad-suite-web/backend
npm install

# 2. Install frontend dependencies
cd ../frontend
npm install

# 3. Start backend (Terminal 1)
cd ../backend
npm start
# Should see: "AD Security Suite Backend running on port 3001"

# 4. Start frontend (Terminal 2)
cd ../frontend
npm run dev
# Should see: "Local: http://localhost:5173"
```

---

## Test Suite 1: Initial Setup & Configuration

### 1.1 Settings Page - Suite Root Configuration
**Test**: Configure and validate suite root path

**Steps**:
1. Navigate to `http://localhost:5173`
2. Click "Settings" in sidebar
3. Enter suite root path: `C:\Users\acer\Downloads\AD_suiteXXX`
4. Click "Validate" button

**Expected Results**:
- ✅ Green checkmark appears
- ✅ Message shows: "Found X checks across Y categories"
- ✅ No errors in browser console
- ✅ No errors in backend terminal

**Troubleshooting**:
- Red X appears → Check path exists and is accessible
- "Path not found" → Verify exact path spelling
- Backend error → Check backend terminal for details

### 1.2 Settings Page - PowerShell Test
**Test**: Verify PowerShell execution

**Steps**:
1. In Settings page, scroll to "PowerShell" section
2. Click "Test PowerShell" button

**Expected Results**:
- ✅ Green checkmark appears
- ✅ Message shows: "PowerShell is working correctly"
- ✅ Backend terminal shows PowerShell execution

**Troubleshooting**:
- Test fails → Check PowerShell is in PATH
- Permission error → Run as Administrator
- Execution policy error → Set to Bypass in Settings

### 1.3 Settings Page - C# Compiler Detection
**Test**: Detect C# compiler (optional)

**Steps**:
1. In Settings page, scroll to "C# Compiler" section
2. Click "Auto-detect csc.exe" button

**Expected Results**:
- ✅ Success message if .NET Framework installed
- ✅ Path populated in input field
- ⚠️ "Not found" message if .NET not installed (acceptable)

### 1.4 Settings Page - Database Operations
**Test**: Database export and management

**Steps**:
1. Click "Export DB as JSON" button
2. Verify file downloads
3. Click "Clear history older than: 30 days" → "Apply"
4. Confirm action

**Expected Results**:
- ✅ Database file downloads successfully
- ✅ Clear history shows success message
- ✅ Database size updates

**⚠️ Warning**: Do NOT test "Reset all data" unless you want to delete everything!

---

## Test Suite 2: Scan Discovery & Selection

### 2.1 Run Scans Page - Check Discovery
**Test**: Discover available checks from suite

**Steps**:
1. Navigate to "Run Scans" page
2. Verify suite root path is shown
3. Click "Validate" if not already validated
4. Scroll to "Select Checks" section

**Expected Results**:
- ✅ Categories appear (Access_Control, Authentication, etc.)
- ✅ Check count shown for each category
- ✅ Checks are selectable
- ✅ "X checks selected across Y categories" updates

**Troubleshooting**:
- No checks appear → Validate suite root first
- "Please validate Suite Root Path" → Go to Settings and validate
- Empty categories → Check suite directory structure

### 2.2 Run Scans Page - Check Selection
**Test**: Select and deselect checks

**Steps**:
1. Expand a category (e.g., "Access_Control")
2. Check individual checks
3. Check category checkbox (selects all in category)
4. Click "Select All" button
5. Click "Clear All" button
6. Use search box to filter checks

**Expected Results**:
- ✅ Individual checks toggle correctly
- ✅ Category checkbox shows indeterminate state when partially selected
- ✅ Select All selects all checks
- ✅ Clear All deselects all checks
- ✅ Search filters checks in real-time
- ✅ Selection count updates correctly

---

## Test Suite 3: Target Configuration

### 3.1 Run Scans Page - Domain Configuration
**Test**: Configure domain targeting

**Steps**:
1. In "Target Configuration" section
2. Enter domain: `corp.domain.local`
3. Observe connection mode badge

**Expected Results**:
- ✅ Domain validates (FQDN format)
- ✅ DN conversion shown: `DC=corp,DC=domain,DC=local`
- ✅ Connection mode shows "Domain-targeted"

### 3.2 Run Scans Page - Server IP Configuration
**Test**: Configure direct server targeting

**Steps**:
1. Enter server IP: `192.168.1.10`
2. Observe connection mode badge

**Expected Results**:
- ✅ IP validates
- ✅ Connection mode shows "Direct" or "Explicit"

### 3.3 Run Scans Page - Target Validation
**Test**: Test LDAP connection (requires real AD)

**Steps**:
1. With domain/IP configured
2. Click "Test Connection" button

**Expected Results**:
- ✅ Success: "Connected — DC=..." shown
- ⚠️ Failure: "Cannot connect: ..." (acceptable if no AD available)

---

## Test Suite 4: Scan Execution

### 4.1 Run Scans Page - Execute Scan
**Test**: Run a complete scan

**Steps**:
1. Ensure suite root validated
2. Select 2-3 checks (start small for testing)
3. Select engine: "ADSI" or "PowerShell"
4. Click "Run Scan" button

**Expected Results**:
- ✅ Status changes to "Scan in Progress"
- ✅ Progress bar appears and updates
- ✅ Terminal component shows live output
- ✅ Check IDs appear in yellow
- ✅ "Done" messages appear in green
- ✅ Errors (if any) appear in red
- ✅ Progress shows "X/Y" checks completed
- ✅ Terminal auto-scrolls to bottom

**Troubleshooting**:
- Scan stuck at 0% → Check backend terminal for errors
- No terminal output → Check SSE connection in Network tab
- PowerShell errors → Check execution policy
- Script not found → Verify suite root path

### 4.2 Run Scans Page - Abort Scan
**Test**: Abort a running scan

**Steps**:
1. Start a scan with many checks
2. Click "Abort Scan" button while running

**Expected Results**:
- ✅ Scan stops immediately
- ✅ Status changes to "Aborted"
- ✅ Partial results shown
- ✅ Terminal shows abort message

### 4.3 Run Scans Page - View Results
**Test**: View scan results after completion

**Steps**:
1. Wait for scan to complete
2. Observe results section

**Expected Results**:
- ✅ Status shows "Scan Complete"
- ✅ Severity breakdown shown (Critical, High, Medium, Low)
- ✅ Findings table appears
- ✅ Terminal output collapsible
- ✅ Export buttons available

### 4.4 Run Scans Page - Export Results
**Test**: Export scan results

**Steps**:
1. After scan completes
2. Click "JSON" button
3. Click "CSV" button

**Expected Results**:
- ✅ JSON file downloads
- ✅ CSV file downloads
- ✅ Files contain findings data
- ✅ Filenames include scan ID

---

## Test Suite 5: Dashboard

### 5.1 Dashboard Page - Data Loading
**Test**: Dashboard displays real data

**Steps**:
1. Navigate to "Dashboard" page
2. Observe all widgets

**Expected Results**:
- ✅ "Last Scan Findings" shows real count
- ✅ "Critical Findings" shows real count
- ✅ Severity pie chart shows real data
- ✅ Category bar chart shows real data
- ✅ Recent scans table shows real scans
- ✅ No hardcoded "775" checks (should be dynamic)

### 5.2 Dashboard Page - Charts
**Test**: Charts render correctly

**Expected Results**:
- ✅ Pie chart shows severity distribution
- ✅ Bar chart shows top categories
- ✅ Tooltips work on hover
- ✅ Colors match severity levels

---

## Test Suite 6: Reports

### 6.1 Reports Page - Scan List
**Test**: View scan history

**Steps**:
1. Navigate to "Reports" page
2. Observe scan list

**Expected Results**:
- ✅ All scans listed
- ✅ Scan details shown (ID, date, engine, counts)
- ✅ Status icons correct
- ✅ Duration formatted correctly

### 6.2 Reports Page - Filters
**Test**: Filter scans

**Steps**:
1. Click "Show Filters"
2. Set date range
3. Select engine filter
4. Use search box

**Expected Results**:
- ✅ Filters apply correctly
- ✅ Scan count updates
- ✅ "Clear Filters" resets all

### 6.3 Reports Page - Single Scan Export
**Test**: Export individual scan

**Steps**:
1. Click download icon on a scan row
2. Verify file downloads

**Expected Results**:
- ✅ JSON file downloads
- ✅ File contains findings
- ✅ Filename includes scan ID

### 6.4 Reports Page - Multi-Scan Export
**Test**: Export multiple scans

**Steps**:
1. Check 2-3 scans
2. Click "Download JSON" in bulk action bar
3. Click "Download CSV"
4. Click "Download PDF (merged)"

**Expected Results**:
- ✅ JSON file downloads with merged data
- ✅ CSV file downloads with merged data
- ✅ PDF file downloads with merged data
- ✅ All findings from selected scans included

### 6.5 Reports Page - Delete Scans
**Test**: Delete scan records

**Steps**:
1. Check 1 scan
2. Click "Delete Selected"
3. Confirm deletion

**Expected Results**:
- ✅ Confirmation dialog appears
- ✅ Scan removed from list
- ✅ Success message shows counts
- ✅ Database size decreases

---

## Test Suite 7: Integrations

### 7.1 Integrations Page - BloodHound Test
**Test**: Test BloodHound connection (requires BH instance)

**Steps**:
1. Navigate to "Integrations" page
2. Enter BloodHound URL: `http://localhost:8080`
3. Enter credentials
4. Click "Test Connection"

**Expected Results**:
- ✅ Success: Green checkmark if BH running
- ⚠️ Failure: Red X if BH not available (acceptable)

### 7.2 Integrations Page - Neo4j Test
**Test**: Test Neo4j connection (requires Neo4j instance)

**Steps**:
1. Enter Bolt URI: `bolt://localhost:7687`
2. Enter credentials
3. Click "Test Connection"

**Expected Results**:
- ✅ Success: Green checkmark if Neo4j running
- ⚠️ Failure: Red X if Neo4j not available (acceptable)

### 7.3 Integrations Page - Push Findings
**Test**: Push findings to integration (requires external service)

**Steps**:
1. Select a scan
2. Configure integration
3. Click "Push Findings"

**Expected Results**:
- ✅ Success message with count
- ✅ Data appears in external system
- ⚠️ Failure if service not available (acceptable)

---

## Test Suite 8: Schedules

### 8.1 Schedules Page - Create Schedule
**Test**: Create a scheduled scan

**Steps**:
1. Navigate to "Schedules" page
2. Click "Create Schedule"
3. Enter name: "Daily Security Scan"
4. Select checks
5. Select engine
6. Enter cron: `0 2 * * *` (2 AM daily)
7. Click "Save"

**Expected Results**:
- ✅ Schedule appears in list
- ✅ Next run time calculated
- ✅ Status shows "Enabled"

### 8.2 Schedules Page - Manual Trigger
**Test**: Manually trigger a schedule

**Steps**:
1. Click "Run Now" on a schedule
2. Navigate to Dashboard to see scan

**Expected Results**:
- ✅ Scan starts immediately
- ✅ Last run time updates
- ✅ Scan appears in recent scans

---

## Test Suite 9: Error Handling

### 9.1 Invalid Suite Root
**Test**: Handle invalid paths gracefully

**Steps**:
1. Enter invalid path: `C:\NonExistent\Path`
2. Click "Validate"

**Expected Results**:
- ✅ Error message shown
- ✅ No crash
- ✅ User can correct and retry

### 9.2 Concurrent Scan Prevention
**Test**: Prevent multiple simultaneous scans

**Steps**:
1. Start a scan
2. Open new tab
3. Try to start another scan

**Expected Results**:
- ✅ Error: "A scan is already running"
- ✅ HTTP 409 status
- ✅ First scan continues unaffected

### 9.3 Network Errors
**Test**: Handle backend disconnection

**Steps**:
1. Stop backend server
2. Try to start a scan

**Expected Results**:
- ✅ Error message shown
- ✅ "Cannot reach backend" message
- ✅ No crash

---

## Test Suite 10: Performance

### 10.1 Large Scan
**Test**: Handle scans with many checks

**Steps**:
1. Select 50+ checks
2. Run scan
3. Monitor performance

**Expected Results**:
- ✅ Terminal updates smoothly
- ✅ No UI freezing
- ✅ Memory usage reasonable
- ✅ Scan completes successfully

### 10.2 Large Findings
**Test**: Handle scans with many findings

**Steps**:
1. Run scan that produces 1000+ findings
2. View results

**Expected Results**:
- ✅ Findings table loads
- ✅ Pagination works
- ✅ Export works
- ✅ No browser crash

---

## Test Suite 11: Browser Compatibility

### 11.1 Chrome/Edge
**Test**: Full functionality in Chromium browsers

**Expected Results**:
- ✅ All features work
- ✅ No console errors
- ✅ SSE streaming works

### 11.2 Firefox
**Test**: Full functionality in Firefox

**Expected Results**:
- ✅ All features work
- ✅ No console errors
- ✅ SSE streaming works

---

## Automated Testing Commands

```bash
# Backend tests (if implemented)
cd backend
npm test

# Frontend tests (if implemented)
cd frontend
npm test

# Linting
cd backend
npm run lint

cd frontend
npm run lint

# Build test
cd frontend
npm run build
```

---

## Test Results Template

```markdown
## Test Session: [Date]
**Tester**: [Name]
**Environment**: [OS, Browser]
**Suite Version**: [Version]

### Results Summary
- Total Tests: X
- Passed: X
- Failed: X
- Skipped: X

### Failed Tests
1. [Test Name]
   - Expected: [...]
   - Actual: [...]
   - Error: [...]

### Notes
- [Any observations]
- [Performance issues]
- [Suggestions]
```

---

## Known Issues & Workarounds

### Issue: PowerShell execution fails
**Workaround**: Run as Administrator or set execution policy to Bypass

### Issue: C# checks don't compile
**Workaround**: Install .NET Framework 4.x or skip C# checks

### Issue: Large scans timeout
**Workaround**: Reduce check count or increase timeout in executor.js

### Issue: Export fails for large datasets
**Workaround**: Export as JSON instead of PDF

---

## Support & Debugging

### Enable Debug Logging

**Backend**:
```javascript
// In server.js, add:
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});
```

**Frontend**:
```javascript
// In browser console:
localStorage.setItem('debug', 'true');
```

### Check Logs

**Backend logs**: Terminal where `npm start` is running
**Frontend logs**: Browser DevTools Console (F12)
**Network logs**: Browser DevTools Network tab

### Common Debug Commands

```bash
# Check backend is running
curl http://localhost:3001/api/health

# Check database
sqlite3 ad-suite-web/data/ad-suite.db "SELECT COUNT(*) FROM scans;"

# Check reports directory
ls ad-suite-web/backend/reports/

# Check PowerShell version
powershell -Command "$PSVersionTable"
```

---

## Test Completion Checklist

- [ ] All Test Suite 1 tests passed
- [ ] All Test Suite 2 tests passed
- [ ] All Test Suite 3 tests passed
- [ ] All Test Suite 4 tests passed
- [ ] All Test Suite 5 tests passed
- [ ] All Test Suite 6 tests passed
- [ ] All Test Suite 7 tests passed (or skipped if no external services)
- [ ] All Test Suite 8 tests passed
- [ ] All Test Suite 9 tests passed
- [ ] All Test Suite 10 tests passed
- [ ] All Test Suite 11 tests passed
- [ ] No critical bugs found
- [ ] Performance acceptable
- [ ] Documentation reviewed
- [ ] Ready for production use

---

**Testing Status**: Ready for UAT
**Last Updated**: Current Session
**Next Review**: After first production deployment


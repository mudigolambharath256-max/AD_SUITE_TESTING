# AD Security Suite - Quick Start Guide

## 🚀 Get Started in 5 Minutes

This guide will get you up and running with the AD Security Suite web application.

---

## Step 1: Prerequisites (2 minutes)

### Required
- ✅ **Node.js 16+** - [Download](https://nodejs.org/)
- ✅ **PowerShell** - Pre-installed on Windows
- ✅ **AD Security Suite Scripts** - Downloaded and extracted

### Optional
- ⚠️ **.NET Framework 4.x** - For C# checks
- ⚠️ **BloodHound** - For integration features
- ⚠️ **Neo4j** - For graph integration

### Verify Prerequisites
```bash
# Check Node.js version
node --version
# Should show: v16.x.x or higher

# Check PowerShell
powershell -Command "Write-Output 'OK'"
# Should show: OK
```

---

## Step 2: Installation (1 minute)

```bash
# Navigate to project directory
cd ad-suite-web

# Install backend dependencies
cd backend
npm install

# Install frontend dependencies
cd ../frontend
npm install
```

**Expected output**: No errors, packages installed successfully

---

## Step 3: Start the Application (30 seconds)

### Option A: Two Terminals (Recommended for Development)

**Terminal 1 - Backend**:
```bash
cd ad-suite-web/backend
npm start
```
Wait for: `AD Security Suite Backend running on port 3001`

**Terminal 2 - Frontend**:
```bash
cd ad-suite-web/frontend
npm run dev
```
Wait for: `Local: http://localhost:5173`

### Option B: Production Mode (Single Terminal)

```bash
# Build frontend
cd ad-suite-web/frontend
npm run build

# Start backend (serves frontend)
cd ../backend
NODE_ENV=production npm start
```
Open: `http://localhost:3001`

---

## Step 4: Initial Configuration (1 minute)

### 4.1 Open the Application
1. Open browser to `http://localhost:5173` (dev) or `http://localhost:3001` (prod)
2. You should see the Dashboard

### 4.2 Configure Suite Root
1. Click **Settings** in the sidebar
2. Enter your suite root path:
   ```
   C:\Users\acer\Downloads\AD_suiteXXX
   ```
   *(Replace with your actual path)*
3. Click **Validate**
4. Wait for green checkmark: "Found X checks across Y categories"

### 4.3 Test PowerShell (Optional)
1. Scroll to "PowerShell" section
2. Click **Test PowerShell**
3. Wait for green checkmark: "PowerShell is working correctly"

**✅ Configuration Complete!**

---

## Step 5: Run Your First Scan (30 seconds)

### 5.1 Navigate to Run Scans
1. Click **Run Scans** in the sidebar

### 5.2 Select Checks
1. Scroll to "Select Checks" section
2. Expand a category (e.g., "Access_Control")
3. Check 2-3 checks for testing
4. Or click **Select All** to run everything

### 5.3 Choose Engine
1. Select engine: **ADSI** (recommended for first scan)

### 5.4 Start Scan
1. Click **Run Scan** button
2. Watch the live terminal output
3. Wait for completion (30 seconds - 5 minutes depending on checks)

### 5.5 View Results
1. See severity breakdown (Critical, High, Medium, Low)
2. Browse findings table
3. Click **JSON** or **CSV** to export

**🎉 First Scan Complete!**

---

## Common Tasks

### Export Scan Results
1. After scan completes
2. Click **JSON**, **CSV**, or **PDF** button
3. File downloads automatically

### View Scan History
1. Click **Reports** in sidebar
2. See all previous scans
3. Click eye icon to view details
4. Click download icon to export

### Schedule Automatic Scans
1. Click **Schedules** in sidebar
2. Click **Create Schedule**
3. Configure checks and cron expression
4. Example: `0 2 * * *` = Daily at 2 AM

### Clear Old Data
1. Click **Settings** in sidebar
2. Scroll to "Database" section
3. Click **Clear history older than: 30 days**
4. Or click **Export DB as JSON** to backup first

---

## Troubleshooting

### Problem: "Suite root not found"
**Solution**: 
- Check path spelling
- Use full path: `C:\Users\...\AD_suiteXXX`
- Ensure directory exists and is accessible

### Problem: "PowerShell test failed"
**Solution**:
- Run as Administrator
- Check execution policy: `Get-ExecutionPolicy`
- Set to Bypass in Settings

### Problem: "No checks found"
**Solution**:
- Verify suite directory structure
- Should contain folders like: Access_Control, Authentication, etc.
- Each folder should contain check subfolders with .ps1 files

### Problem: "Scan stuck at 0%"
**Solution**:
- Check backend terminal for errors
- Verify PowerShell is working
- Try with fewer checks first

### Problem: "Cannot reach backend"
**Solution**:
- Ensure backend is running on port 3001
- Check for port conflicts
- Restart backend: `npm start`

### Problem: "Export download fails"
**Solution**:
- Ensure scan completed successfully
- Check backend terminal for errors
- Try JSON export first (smallest file)

---

## Next Steps

### Learn More
- 📖 Read [TESTING_GUIDE.md](./TESTING_GUIDE.md) for comprehensive testing
- 📖 Read [FINAL_IMPLEMENTATION_STATUS.md](./FINAL_IMPLEMENTATION_STATUS.md) for features
- 📖 Read [new_fix.md](./new_fix.md) for technical details

### Advanced Features
- **Target Specific Domain**: Enter domain FQDN in Run Scans
- **Target Specific DC**: Enter server IP in Run Scans
- **BloodHound Integration**: Configure in Integrations page
- **Neo4j Integration**: Configure in Integrations page
- **Scheduled Scans**: Set up in Schedules page

### Customize
- **Execution Policy**: Change in Settings → PowerShell
- **C# Compiler**: Auto-detect in Settings → C# Compiler
- **Table Density**: Change in Settings → Appearance
- **Terminal Font Size**: Adjust in Settings → Appearance

---

## Architecture Overview

```
ad-suite-web/
├── backend/                 # Node.js + Express API
│   ├── routes/             # API endpoints
│   ├── services/           # Business logic
│   └── data/               # SQLite database
├── frontend/               # React + Vite UI
│   ├── src/
│   │   ├── pages/         # Main pages
│   │   ├── components/    # Reusable components
│   │   └── lib/           # Utilities
│   └── dist/              # Production build
└── reports/               # Generated scan reports
```

### Technology Stack
- **Backend**: Node.js, Express, SQLite, better-sqlite3
- **Frontend**: React, Vite, Zustand, TailwindCSS
- **Streaming**: Server-Sent Events (SSE)
- **Scheduling**: node-cron
- **Export**: csv-stringify, pdfkit

---

## Production Deployment

### Build for Production
```bash
# Build frontend
cd ad-suite-web/frontend
npm run build

# Start production server
cd ../backend
NODE_ENV=production npm start
```

### Run as Windows Service (Optional)
```bash
# Install node-windows
npm install -g node-windows

# Create service script
node create-service.js
```

### Configure Firewall (Optional)
```bash
# Allow port 3001
netsh advfirewall firewall add rule name="AD Suite" dir=in action=allow protocol=TCP localport=3001
```

---

## Security Considerations

### Local Tool
- Designed for **single-user local use**
- No authentication required
- Runs on localhost only

### PowerShell Execution
- Uses **Bypass** execution policy
- Required for unsigned scripts
- Only affects this application

### Database
- SQLite file stored locally
- No encryption (relies on file system security)
- Backup regularly using "Export DB"

### API Keys
- Stored in browser localStorage
- Only for integrations (BloodHound, Neo4j, MCP)
- Never sent to external servers except target integration

---

## Performance Tips

### For Large Scans
- Start with fewer checks to test
- Use ADSI engine (fastest)
- Close other applications
- Monitor Task Manager for resource usage

### For Large Findings
- Export as JSON (fastest)
- Use pagination in findings table
- Clear old history regularly
- Export and archive old scans

### For Scheduled Scans
- Schedule during off-hours (2-4 AM)
- Limit concurrent checks
- Enable auto-export to save results
- Monitor disk space for reports

---

## Support & Resources

### Documentation
- [TESTING_GUIDE.md](./TESTING_GUIDE.md) - Complete testing procedures
- [FINAL_IMPLEMENTATION_STATUS.md](./FINAL_IMPLEMENTATION_STATUS.md) - Feature list
- [IMPLEMENTATION_COMPLETE.md](./IMPLEMENTATION_COMPLETE.md) - Implementation details

### Getting Help
1. Check browser console (F12) for errors
2. Check backend terminal for errors
3. Review troubleshooting section above
4. Check [TESTING_GUIDE.md](./TESTING_GUIDE.md) for detailed tests

### Reporting Issues
When reporting issues, include:
- Error message (exact text)
- Browser console output
- Backend terminal output
- Steps to reproduce
- Operating system and Node.js version

---

## Quick Reference

### Keyboard Shortcuts
- `Ctrl + Shift + I` - Open DevTools
- `F5` - Refresh page
- `Ctrl + F` - Search in findings

### Default Ports
- Frontend (dev): `5173`
- Backend: `3001`
- BloodHound: `8080`
- Neo4j: `7687`

### File Locations
- Database: `backend/data/ad-suite.db`
- Reports: `backend/reports/<scanId>/`
- Logs: Backend terminal output

### API Endpoints
- Health: `GET /api/health`
- Run Scan: `POST /api/scan/run`
- Export: `POST /api/reports/export`
- Settings: `GET /api/settings/:key`

---

## Success Checklist

- [ ] Backend running on port 3001
- [ ] Frontend accessible at localhost:5173
- [ ] Suite root validated successfully
- [ ] PowerShell test passed
- [ ] First scan completed
- [ ] Results exported successfully
- [ ] Dashboard showing real data
- [ ] No errors in console

**✅ You're ready to use AD Security Suite!**

---

**Version**: 1.0.0
**Last Updated**: Current Session
**Status**: Production Ready

**Happy Scanning! 🛡️**


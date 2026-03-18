# Quick Start - Domain-Joined Machine

## 🚀 Get Started in 5 Minutes

### Step 1: Clone Repository
```bash
git clone -b development https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
cd AD_SUITE_TESTING/ad-suite-web
```

### Step 2: Install Dependencies
```bash
# Backend
cd backend
npm install

# Frontend
cd ../frontend
npm install
```

### Step 3: Start Services
```bash
# Terminal 1 - Backend
cd ad-suite-web/backend
npm start

# Terminal 2 - Frontend
cd ad-suite-web/frontend
npm run dev
```

### Step 4: Access Website
Open browser: **http://localhost:5173**

---

## ✅ What's Fixed (Latest Version)

- ✅ **JSON Parsing Errors** - BOM characters handled automatically
- ✅ **Null Reference Errors** - Safe property access throughout
- ✅ **Missing Properties** - Fallback values for incomplete AD objects
- ✅ **Attack Labels** - Proper labeling for security findings
- ✅ **Error Resilience** - Graceful handling of malformed data

---

## 🔥 Common Commands

### Update to Latest Version
```bash
cd AD_SUITE_TESTING
git pull origin development
cd ad-suite-web/backend && npm install
cd ../frontend && npm install
```

### Check Backend Health
```bash
curl http://localhost:3001/api/health
```

### View Backend Logs
Check the terminal where you ran `npm start` in the backend folder

### Test BloodHound API
```bash
# Replace SCAN_ID with actual scan ID
curl http://localhost:3001/api/bloodhound/scan/SCAN_ID
```

---

## 🛠️ Troubleshooting

### Issue: "Cannot connect to backend"
**Solution**: 
1. Check backend is running: `curl http://localhost:3001/api/health`
2. Check firewall settings
3. Restart backend: `npm start`

### Issue: "JSON parsing error"
**Solution**: Already fixed! Pull latest: `git pull origin development`

### Issue: "Null reference error"
**Solution**: Already fixed! Pull latest: `git pull origin development`

### Issue: "Graph shows no data"
**Check**:
1. Did the scan complete successfully?
2. Are there findings in the scan results?
3. Check browser console for errors (F12)
4. Check backend terminal for errors

---

## 📁 Important Files

- **Backend**: `ad-suite-web/backend/server.js`
- **Frontend**: `ad-suite-web/frontend/src/`
- **BloodHound Routes**: `ad-suite-web/backend/routes/bloodhound.js`
- **Configuration**: `ad-suite-web/backend/.env` (create if needed)

---

## 🔒 Firewall Configuration (Optional)

If accessing from other machines on the network:

```powershell
# Run as Administrator
New-NetFirewallRule -DisplayName "AD Suite Backend" -Direction Inbound -LocalPort 3001 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "AD Suite Frontend" -Direction Inbound -LocalPort 5173 -Protocol TCP -Action Allow
```

Then access from other machines:
- Frontend: `http://DOMAIN_MACHINE_IP:5173`
- Backend: `http://DOMAIN_MACHINE_IP:3001`

---

## 📚 Documentation

- **Full Setup Guide**: `DOMAIN_SETUP_GUIDE.md`
- **Fix Details**: `DOMAIN_FIXES_SUMMARY.md`
- **Installation**: `INSTALL.md`

---

## 🎯 Quick Test

1. Open http://localhost:5173
2. Go to Dashboard
3. Click "Run New Scan"
4. Select 2-3 checks (e.g., AUTH-001, ACC-001)
5. Click "Start Scan"
6. Wait for completion
7. Go to Integration → AD Graph Visualizer
8. Should see nodes and relationships

**Expected**: No errors, graph displays correctly

---

## 💡 Tips

- Run backend on the domain-joined machine for best results
- Ensure user has AD read permissions
- Use PowerShell as Administrator if permission errors occur
- Check backend logs for detailed error messages
- Frontend and backend can run on different machines

---

**Version**: Development Branch (Latest)  
**Last Updated**: March 18, 2026  
**Status**: ✅ Production Ready for Domain Environments

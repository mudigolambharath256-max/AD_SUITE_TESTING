# Testing Guide: Graph Features

## Prerequisites

1. Ensure all dependencies are installed:
   ```bash
   cd ad-suite-web
   npm run install-all
   ```

2. Verify cytoscape is installed:
   ```bash
   cd frontend
   npm list cytoscape
   # Should show: cytoscape@3.33.1
   ```

## Starting the Application

### Option 1: Full Development Mode (Recommended)
```bash
cd ad-suite-web
npm run dev
```
This starts both backend (port 3001) and frontend (port 5173) concurrently.

### Option 2: Separate Terminals
Terminal 1 (Backend):
```bash
cd ad-suite-web/backend
npm run dev
```

Terminal 2 (Frontend):
```bash
cd ad-suite-web/frontend
npm run dev
```

## Testing Checklist

### 1. Verify Page Loads
- [ ] Navigate to http://localhost:5173
- [ ] Click on "Integrations" in the sidebar
- [ ] Scroll to the bottom of the page
- [ ] Verify you see two new sections:
  - "ADExplorer Snapshot Converter"
  - "AD Graph Visualiser"

### 2. Test ADExplorer Converter UI
- [ ] Verify snapshot file input field is visible
- [ ] Verify convertsnapshot.exe path input is visible
- [ ] Verify "Browse" buttons are present
- [ ] Verify "Convert Snapshot" button is visible
- [ ] Verify info link to GitHub repo is present

### 3. Test Graph Visualiser UI
- [ ] Verify data source toggle buttons (ADExplorer Session / Scan Findings)
- [ ] Verify session ID input field (when ADExplorer is selected)
- [ ] Verify scan dropdown (when Scan Findings is selected)
- [ ] Verify "Load Graph" button is visible
- [ ] Verify empty state message: "Select a data source and click Load Graph"

### 4. Test ADExplorer Converter (Without Real File)
**Expected Behavior: Error handling**

- [ ] Leave snapshot path empty, click "Convert Snapshot"
- [ ] Should show error: "Please provide a snapshot file path"
- [ ] Enter fake path: `C:\fake\snapshot.dat`
- [ ] Click "Convert Snapshot"
- [ ] Should show error in progress log: "Snapshot file not found"

### 5. Test Graph Visualiser (With Scan Data)
**If you have existing scan data:**

- [ ] Select "Scan Findings" data source
- [ ] Choose a scan from the dropdown
- [ ] Click "Load Graph"
- [ ] Verify loading spinner appears
- [ ] Verify graph renders with nodes and edges
- [ ] Verify graph controls appear (node count, layout picker, filter)
- [ ] Click a node - properties panel should appear on the right
- [ ] Change layout (try "Circle", "Grid", "Force-directed")
- [ ] Test filter dropdown (try filtering by node type)
- [ ] Click "⊡ Fit" button - graph should fit to viewport
- [ ] Click "↓ PNG" button - should download ad-graph.png

### 6. Test Component Communication
**This requires a successful ADExplorer conversion:**

- [ ] After conversion completes, verify "graph.json" appears in output files
- [ ] Click "📊 Open in Graph Visualiser" button
- [ ] Verify Graph Visualiser section automatically loads the graph
- [ ] Verify session ID is populated in the input field

### 7. Backend API Endpoints
**Test with curl or browser:**

```bash
# Health check
curl http://localhost:3001/api/health

# Test graph-data endpoint (replace SCAN_ID with actual scan ID)
curl http://localhost:3001/api/reports/graph-data/SCAN_ID

# Test ADExplorer routes (should return 400 without valid data)
curl -X POST http://localhost:3001/api/integrations/adexplorer/convert \
  -H "Content-Type: application/json" \
  -d '{"snapshotPath":"test.dat"}'
```

## Testing with Real ADExplorer Snapshot

### Obtaining a Test Snapshot
1. Download ADExplorer from Sysinternals:
   https://learn.microsoft.com/en-us/sysinternals/downloads/adexplorer

2. Run ADExplorer.exe on a domain-joined machine

3. File → Create Snapshot → Save as .dat file

4. Note the full path (e.g., `C:\Snapshots\domain_snapshot.dat`)

### Testing Conversion
1. Enter the full path to your .dat file
2. (Optional) Download convertsnapshot.exe from:
   https://github.com/t94j0/adexplorersnapshot-rs/releases
3. Enter path to convertsnapshot.exe if available
4. Click "Convert Snapshot"
5. Watch the progress log for:
   - "Parsing binary snapshot with PowerShell BinaryReader..."
   - "Server: [domain] | Objects: [count]"
   - "Parsed: X users, Y groups, Z computers..."
   - "Writing BloodHound JSON files..."
   - "graph.json written: X nodes, Y edges"
6. Verify output files appear:
   - `DOMAIN_users.json`
   - `DOMAIN_groups.json`
   - `DOMAIN_computers.json`
   - `DOMAIN_domains.json`
   - `graph.json`
7. Test download buttons
8. Test "Open in Graph Visualiser" button

## Common Issues & Solutions

### Issue: "Cannot find module 'cytoscape'"
**Solution:**
```bash
cd ad-suite-web/frontend
npm install cytoscape
```

### Issue: Backend route not found (404)
**Solution:**
- Verify backend/routes/adexplorer.js exists
- Check backend/server.js has the route registration
- Restart the backend server

### Issue: Graph doesn't render
**Solution:**
- Open browser console (F12)
- Check for JavaScript errors
- Verify graph data has nodes array with at least one node
- Check cytoscape container has height (should be 520px)

### Issue: PowerShell script fails
**Solution:**
- Check PowerShell execution policy: `Get-ExecutionPolicy`
- Script uses `-ExecutionPolicy Bypass` flag
- Verify .dat file path is correct and accessible
- Check backend console for detailed error messages

### Issue: SSE connection fails
**Solution:**
- Check browser console for EventSource errors
- Verify backend is running on port 3001
- Check CORS settings in backend/server.js

## Browser Console Debugging

Open browser console (F12) and check for:

**Expected console messages:**
- No errors on page load
- Cytoscape initialization messages when graph loads
- Network requests to `/api/integrations/adexplorer/*` endpoints

**Common errors to watch for:**
- CORS errors (backend not running)
- 404 errors (route not registered)
- Module import errors (cytoscape not installed)
- React component errors (check component syntax)

## Performance Notes

- Large snapshots (>100MB) may take several minutes to parse
- Graph rendering with >1000 nodes may be slow
- Consider using "Force-directed" layout for best performance
- PNG export may take a few seconds for large graphs

## Next Steps After Testing

1. If all tests pass, the implementation is complete
2. Consider adding:
   - Session persistence (save to database)
   - Progress percentage calculation
   - Graph search/filter by properties
   - Export to other formats (SVG, JSON)
   - Batch conversion support
3. Document any issues found
4. Create user documentation with screenshots

## Support

If you encounter issues:
1. Check browser console for errors
2. Check backend terminal for errors
3. Verify all files were created correctly
4. Review GRAPH_FEATURES_IMPLEMENTATION.md
5. Check the specification in graph_crea.md

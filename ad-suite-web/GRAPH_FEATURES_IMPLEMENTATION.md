# Graph Features Implementation Summary

## Overview
Successfully implemented two new independent features for the AD Security Suite Integrations page:

1. **ADExplorer Snapshot Converter** - Converts Sysinternals ADExplorer .dat files to BloodHound JSON
2. **AD Graph Visualiser** - Interactive graph visualization using cytoscape.js

## Files Created

### Backend
- `backend/scripts/Parse-ADExplorerSnapshot.ps1` - PowerShell parser for ADExplorer snapshots
  - Track 1: Uses convertsnapshot.exe if available (optional external tool)
  - Track 2: Pure PowerShell BinaryReader parser (fallback)
  - Outputs BloodHound v4 JSON format + unified graph.json

- `backend/routes/adexplorer.js` - Express routes for ADExplorer conversion
  - POST `/api/integrations/adexplorer/convert` - Start conversion
  - GET `/api/integrations/adexplorer/stream/:sessionId` - SSE progress stream
  - GET `/api/integrations/adexplorer/graph/:sessionId` - Get graph.json
  - GET `/api/integrations/adexplorer/files/:sessionId` - List output files
  - GET `/api/integrations/adexplorer/download/:sessionId/:filename` - Download file

### Frontend
- `frontend/src/components/AdExplorerSection.jsx` - ADExplorer converter UI
  - File path inputs with browse buttons
  - Real-time progress log via SSE
  - Output file list with download/push actions
  - "Open in Graph Visualiser" button for graph.json

- `frontend/src/components/AdGraphVisualiser.jsx` - Interactive graph component
  - Cytoscape.js integration
  - Multiple data sources (ADExplorer sessions or scan findings)
  - Interactive node selection with properties panel
  - Layout options (Force-directed, Circle, Grid, Breadth-first, Concentric)
  - Node type filtering
  - PNG export
  - Color-coded node types (User, Group, Computer, Domain, OU, Category, Finding)

## Files Modified

### Backend
- `backend/server.js`
  - Added `adexplorerRoutes` import and route registration
  - Added `/api/reports/graph-data/:scanId` endpoint for scan findings graph data

### Frontend
- `frontend/src/pages/Integrations.jsx`
  - Added imports for AdExplorerSection and AdGraphVisualiser
  - Added `graphSessionId` state for component communication
  - Added both new sections at the bottom of the page

## Dependencies Added
- `cytoscape` (frontend) - Pure JavaScript graph visualization library

## Key Features

### ADExplorer Converter
- Supports both convertsnapshot.exe (optimal) and pure PowerShell parsing
- Real-time progress streaming via Server-Sent Events
- Generates BloodHound-compatible JSON files (users, groups, computers, domains)
- Creates unified graph.json for visualization
- Download individual JSON files
- Push to BloodHound integration
- Session-based output management

### Graph Visualiser
- Load data from ADExplorer sessions or scan findings
- Interactive node graph with zoom, pan, fit controls
- Click nodes to view properties in side panel
- Multiple layout algorithms
- Filter by node type
- Export graph as PNG
- Color-coded nodes by type
- Edge relationships (MemberOf, BelongsTo, etc.)

## Data Flow

1. User uploads ADExplorer .dat file
2. Backend spawns PowerShell script to parse binary
3. Script outputs BloodHound JSON + graph.json
4. User can download files or push to BloodHound
5. User clicks "Open in Graph Visualiser"
6. Graph Visualiser loads graph.json via sessionId
7. Cytoscape renders interactive graph
8. User can explore nodes, change layouts, export PNG

## Testing Checklist

- [x] Backend route registration (no errors on server start)
- [x] PowerShell script syntax validation
- [x] Cytoscape package installation
- [x] Frontend component compilation (no TypeScript/ESLint errors)
- [x] File structure created (uploads/adexplorer directory)

## Next Steps for Testing

1. Start the development server: `npm run dev` (from ad-suite-web root)
2. Navigate to Integrations page
3. Scroll to bottom to see new sections
4. Test ADExplorer converter with a .dat file
5. Test Graph Visualiser with scan findings
6. Verify "Open in Graph Visualiser" button works
7. Test all graph controls (layouts, filters, export)

## Notes

- All existing integrations (BloodHound, Neo4j, MCP) remain unchanged
- No modifications to scan execution, reports, or other core features
- Pure client-side graph rendering (no server-side graph processing)
- Session data stored in memory (consider persistence for production)
- File paths use Windows-style paths (C:\path\to\file.dat)

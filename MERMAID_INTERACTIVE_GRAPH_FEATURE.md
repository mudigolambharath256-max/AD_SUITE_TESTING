# Mermaid Interactive Graph Feature

## Overview
Added interactive functionality to the Mermaid attack path diagram where clicking on nodes expands a side panel showing related findings.

## Features Implemented

### 1. Interactive Node Clicking
- Click any node in the Mermaid diagram to see related findings
- Hover effects on nodes (opacity change + scale animation)
- Smooth transitions when expanding/collapsing the findings panel

### 2. Smart Finding Matching
The system intelligently matches findings to nodes based on:
- Node label text
- Finding names
- Check names
- Categories
- Descriptions
- Distinguished names

**Matching Algorithm:**
- Splits node label into search terms
- Searches for terms (>3 characters) in all finding fields
- Returns all findings that match any search term

### 3. Findings Side Panel
When a node is clicked, a side panel slides in showing:
- **Node name** - Highlighted with blue accent
- **Related findings count**
- **Finding cards** with:
  - Check name
  - Severity badge (color-coded)
  - Object name
  - Category
  - MITRE ATT&CK technique
  - Description

### 4. Visual Design
- **Diagram area**: Shrinks to 60% width when panel is open
- **Findings panel**: Takes 38% width with smooth slide-in animation
- **Color coding**: Severity-based colors (Critical=Red, High=Orange, etc.)
- **Close button**: X button to dismiss the panel
- **Responsive layout**: Flexbox-based for smooth resizing

### 5. User Experience
- **Hover feedback**: Nodes scale up and fade slightly on hover
- **Click feedback**: Panel slides in from the right
- **Close options**: Click X button to close panel
- **No findings message**: Shows helpful message if no matches found

## Technical Implementation

### Component: MermaidGraph.jsx

**New Props:**
```javascript
<MermaidGraph 
  chart={mermaidChart}        // Mermaid diagram syntax
  findings={findings}          // Array of finding objects
  onNodeClick={callback}       // Optional callback function
/>
```

**State Management:**
- `selectedNode` - Currently selected node label
- `nodeFindings` - Array of findings related to selected node

**Key Functions:**
- `findRelatedFindings(nodeLabel, allFindings)` - Matches findings to node
- `getSeverityColor(severity)` - Returns color for severity level

### Integration: AttackPath.jsx

**Updated to pass findings:**
```javascript
<MermaidGraph 
  chart={mermaidChart} 
  findings={findings}  // Pass findings array
/>
```

## Usage Example

1. User runs LLM analysis on findings
2. Mermaid diagram is generated and displayed
3. User clicks on a node (e.g., "ASREPRoast User")
4. Side panel slides in showing:
   - All findings related to ASREPRoasting
   - User accounts without Kerberos pre-auth
   - Related MITRE techniques
5. User can review details and close panel

## Benefits

1. **Contextual Information**: See detailed findings for each attack step
2. **Better Understanding**: Connect abstract attack paths to concrete findings
3. **Efficient Navigation**: No need to scroll through all findings
4. **Visual Feedback**: Clear indication of which node is selected
5. **Professional UI**: Smooth animations and clean design

## Future Enhancements

Potential improvements:
- Add filtering options in the findings panel
- Show finding count badge on nodes
- Add export functionality for selected node findings
- Implement multi-node selection
- Add search within findings panel
- Show relationship lines between findings

## Color Scheme

**Severity Colors:**
- CRITICAL: #DC2626 (Red)
- HIGH: #EA580C (Orange)
- MEDIUM: #F59E0B (Amber)
- LOW: #10B981 (Green)
- INFO: #3B82F6 (Blue)

**UI Colors:**
- Background: #1a1612
- Card Background: #2a2420
- Text Primary: #F5F1ED
- Text Secondary: #C9BFB5
- Text Muted: #999
- Accent: #4A90E2 (Blue)

## Testing

To test the feature:
1. Navigate to Attack Path Analysis page
2. Load sample data (GOAD or Advanced)
3. Enter API key and run analysis
4. Wait for Mermaid diagram to render
5. Click on any node in the diagram
6. Verify findings panel appears with relevant findings
7. Click X to close panel
8. Try clicking different nodes

## Performance

- **Rendering**: Fast, uses native Mermaid rendering
- **Matching**: O(n*m) where n=findings, m=search terms (optimized with early termination)
- **Animation**: CSS-based, hardware accelerated
- **Memory**: Minimal overhead, findings already in memory

---

**Status**: ✅ Implemented and Ready
**Version**: 1.0.0
**Date**: March 23, 2026

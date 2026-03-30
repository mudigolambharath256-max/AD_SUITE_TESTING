# Dashboard Page - Complete Documentation

## 📊 Overview

The Dashboard is the main landing page that provides a comprehensive security overview of the Active Directory environment, displaying real-time statistics, severity distributions, vulnerability categories, and recent scan activity.

---

## 🎨 UI Elements

### 1. Header Section
**Location**: Top of page
**Elements**:
- **Title**: "Dashboard" (h1, 3xl, bold, orange)
- **Subtitle**: "Security overview and recent activity" (gray text)

### 2. Metrics Grid (4 Cards)
**Layout**: 4-column grid (responsive: 1 col mobile, 2 cols tablet, 4 cols desktop)

#### Card 1: Total Checks
- **Icon**: Shield (blue/info color)
- **Label**: "Total Checks"
- **Value**: Number of checks executed
- **Color**: Info blue (#8b9cb3)
- **Hover**: Orange border

#### Card 2: Total Findings
- **Icon**: AlertTriangle (medium/yellow color)
- **Label**: "Total Findings"
- **Value**: Sum of all findings across all severities
- **Color**: Medium yellow (#d29922)
- **Hover**: Orange border

#### Card 3: Critical Exposure
- **Icon**: AlertTriangle (critical/red color)
- **Label**: "Critical Exposure"
- **Value**: Count of critical severity findings
- **Color**: Critical red (#f85149)
- **Hover**: Red border
- **Special**: Text color is red to emphasize urgency

#### Card 4: Active Scans
- **Icon**: Activity (green color)
- **Label**: "Active Scans"
- **Value**: Number of currently running scans
- **Color**: Green (#00C851)
- **Hover**: Green border

### 3. Charts Section (2 Charts)
**Layout**: 2-column grid (responsive: 1 col mobile, 2 cols desktop)

#### Chart 1: Severity Distribution (Pie Chart)
- **Type**: Donut/Pie chart
- **Library**: Recharts
- **Data**: Breakdown by severity (Critical, High, Medium, Low, Info)
- **Colors**:
  - Critical: #ff4444 (Red)
  - High: #ff8800 (Orange)
  - Medium: #ffbb33 (Yellow)
  - Low: #00C851 (Green)
  - Info: #33b5e5 (Blue)
- **Features**:
  - Inner radius: 70px
  - Outer radius: 100px
  - Padding angle: 5°
  - Animated (1500ms)
  - Tooltip on hover
- **Empty State**: "No severity data available"

#### Chart 2: Top Vulnerability Categories (Bar Chart)
- **Type**: Horizontal bar chart
- **Library**: Recharts
- **Data**: Top 8 categories by finding count
- **Color**: Yellow (#ffbb33)
- **Features**:
  - Sorted by count (descending)
  - Truncates long names (20 chars + "...")
  - Rounded corners on bars
  - Animated (1500ms)
  - Tooltip on hover
- **Empty State**: "No category data available"

### 4. Recent Scans Table
**Layout**: 2/3 width on desktop, full width on mobile
**Columns**:
1. **Scan Context**: Icon + Scan ID
2. **Status**: Badge (Completed/Running/Failed)
3. **Findings**: Count of total findings
4. **Time**: Timestamp (localized)
5. **Actions**: Download button

**Features**:
- Hover effect on rows (background change)
- Server icon for each scan
- Status badge with icon (CheckCircle for completed)
- Download button (JSON format)
- "View all" link to Reports page
- Empty state: "No recent scans detected" with Activity icon

### 5. Quick Actions Panel
**Layout**: 1/3 width on desktop, full width on mobile
**Background**: Decorative orange glow effect (top-right)

**Action Buttons** (4 total):

#### Button 1: Run Full Suite
- **Icon**: Activity (orange)
- **Label**: "Run Full Suite"
- **Action**: Navigate to /scans
- **Style**: Primary button with shadow
- **Hover**: Orange border, background glow, arrow slides right

#### Button 2: Kerberos Checks
- **Icon**: Shield (gray → orange on hover)
- **Label**: "Kerberos Checks"
- **Action**: Navigate to /scans?category=Kerberos_Security
- **Style**: Secondary button
- **Hover**: Orange border, icon color change

#### Button 3: Privileged Access
- **Icon**: Shield (gray → orange on hover)
- **Label**: "Privileged Access"
- **Action**: Navigate to /scans?category=Privileged_Access
- **Style**: Secondary button
- **Hover**: Orange border, icon color change

#### Button 4: View Reports
- **Icon**: Search
- **Label**: "View Reports"
- **Action**: Navigate to /reports
- **Style**: Tertiary button with inset shadow
- **Hover**: Orange border

---

## 🔌 Backend Integration

### API Endpoints

#### 1. GET /api/dashboard/stats
**Purpose**: Fetch dashboard statistics
**Authentication**: Required (JWT token)
**Response**:
```typescript
{
  totalChecks: number;        // Total number of checks executed
  severityData: {             // Findings count by severity
    critical: number;
    high: number;
    medium: number;
    low: number;
    info: number;
  };
  categoryData: {             // Findings count by category
    [categoryName: string]: number;
  };
  activeScans: number;        // Currently running scans
}
```

**Example Response**:
```json
{
  "totalChecks": 661,
  "severityData": {
    "critical": 45,
    "high": 123,
    "medium": 89,
    "low": 34,
    "info": 12
  },
  "categoryData": {
    "Access_Control": 156,
    "Kerberos_Security": 89,
    "Group_Policy": 67,
    "Privileged_Access": 45
  },
  "activeScans": 0
}
```

#### 2. GET /api/dashboard/recent
**Purpose**: Fetch recent scan history
**Authentication**: Required (JWT token)
**Response**:
```typescript
{
  recent: Array<{
    id: string;              // Scan identifier (filename)
    timestamp: number;       // Unix timestamp (milliseconds)
    status: string;          // "completed" | "running" | "failed"
    totalFindings: number;   // Sum of all findings
  }>;
}
```

**Example Response**:
```json
{
  "recent": [
    {
      "id": "scan-2026-03-27.json",
      "timestamp": 1711526836000,
      "status": "completed",
      "totalFindings": 342
    }
  ]
}
```

---

## 🔄 Data Flow

### 1. Page Load Sequence

```
User navigates to Dashboard
    ↓
Dashboard component mounts
    ↓
React Query triggers API calls (parallel)
    ├─→ GET /api/dashboard/stats
    └─→ GET /api/dashboard/recent
    ↓
Backend reads scan results from ./out directory
    ↓
Backend parses JSON files
    ↓
Backend aggregates data:
    ├─→ Counts findings by severity
    ├─→ Counts findings by category
    └─→ Extracts recent scan metadata
    ↓
Backend returns JSON responses
    ↓
Frontend receives data
    ↓
React Query caches data (queryKey: 'dashboard-stats', 'dashboard-recent')
    ↓
useMemo hooks process data:
    ├─→ severityPieData (for pie chart)
    ├─→ categoryBarData (for bar chart, top 8)
    └─→ totalFindings (sum of all severities)
    ↓
Components render with data
    ↓
Charts animate (1500ms duration)
```

### 2. Backend Data Processing

**File**: `AD-Suite-Web/backend/src/routes/dashboard.ts`

**Function**: `getAvailableScans()`
```typescript
1. Read ./out directory
2. Filter for .json files
3. For each file:
   - Read file content
   - Remove BOM if present
   - Parse JSON
   - Extract results array
   - Extract timestamp from meta
4. Sort by timestamp (newest first)
5. Return array of scan objects
```

**Endpoint**: `/api/dashboard/stats`
```typescript
1. Call getAvailableScans()
2. If no scans, return default values
3. Take latest scan (index 0)
4. Initialize counters:
   - severityData: { critical: 0, high: 0, medium: 0, low: 0, info: 0 }
   - categoryData: {}
5. Loop through results:
   - Extract severity (lowercase)
   - Extract category
   - Extract finding count
   - If count > 0:
     - Increment severityData[severity] by count
     - Increment categoryData[category] by count
6. Return aggregated data
```

**Endpoint**: `/api/dashboard/recent`
```typescript
1. Call getAvailableScans()
2. Take first 10 scans
3. For each scan:
   - Calculate totalFindings (sum of all FindingCount)
   - Create object with id, timestamp, status, totalFindings
4. Return array
```

### 3. Frontend Data Processing

**File**: `AD-Suite-Web/frontend/src/pages/Dashboard.tsx`

**useMemo: severityPieData**
```typescript
1. Check if stats.severityData exists
2. Convert object to array of entries
3. Filter out entries with value = 0
4. Map to chart format:
   - name: Capitalized severity name
   - value: Count
   - rawName: Original severity (for color lookup)
5. Return array for Recharts
```

**useMemo: categoryBarData**
```typescript
1. Check if stats.categoryData exists
2. Convert object to array of entries
3. Sort by count (descending)
4. Take top 8 categories
5. Map to chart format:
   - name: Truncated category name (20 chars max)
   - Findings: Count
6. Return array for Recharts
```

**useMemo: totalFindings**
```typescript
1. Check if stats.severityData exists
2. Get all values (counts)
3. Sum using reduce
4. Return total
```

---

## 🎯 User Interactions

### 1. Metric Cards
- **Hover**: Border changes to orange (or respective color)
- **Click**: No action (display only)

### 2. Charts
- **Hover over segments/bars**: Tooltip appears with exact values
- **Click**: No action (display only)

### 3. Recent Scans Table
- **Hover over row**: Background changes to hover color
- **Click download button**: Downloads scan results as JSON
  - Creates temporary `<a>` element
  - Sets href to `/api/reports/export/{scanId}/json`
  - Triggers download
  - Filename: `scan_{scanId}_findings.json`

### 4. Quick Action Buttons
- **Run Full Suite**: Navigate to /scans page
- **Kerberos Checks**: Navigate to /scans with category filter
- **Privileged Access**: Navigate to /scans with category filter
- **View Reports**: Navigate to /reports page
- **Hover**: Border turns orange, arrow slides right, icon color changes

---

## 🔧 Technical Details

### State Management
- **React Query**: Handles API calls, caching, and refetching
- **Query Keys**:
  - `['dashboard-stats']` - Statistics data
  - `['dashboard-recent']` - Recent scans data
- **Cache Duration**: Default (5 minutes)
- **Refetch**: On window focus (disabled), on mount (enabled)

### Performance Optimizations
1. **useMemo**: Prevents unnecessary recalculations
   - severityPieData
   - categoryBarData
   - totalFindings
2. **React Query Caching**: Reduces API calls
3. **Parallel API Calls**: Both endpoints called simultaneously
4. **Lazy Loading**: Charts only render when data available

### Responsive Design
- **Mobile (< 768px)**:
  - Metrics: 1 column
  - Charts: 1 column (stacked)
  - Table: Horizontal scroll
  - Quick Actions: Full width
- **Tablet (768px - 1024px)**:
  - Metrics: 2 columns
  - Charts: 1 column (stacked)
  - Table: 2/3 width
  - Quick Actions: 1/3 width
- **Desktop (> 1024px)**:
  - Metrics: 4 columns
  - Charts: 2 columns (side by side)
  - Table: 2/3 width
  - Quick Actions: 1/3 width

### Animations
- **Page Load**: Fade in + slide up (500ms)
- **Charts**: Animate on render (1500ms)
- **Hover Effects**: Smooth transitions (150-300ms)
- **Button Arrows**: Slide right on hover

---

## 📁 File Structure

```
AD-Suite-Web/
├── frontend/src/pages/
│   └── Dashboard.tsx          # Main dashboard component
├── backend/src/routes/
│   └── dashboard.ts           # Dashboard API endpoints
└── backend/out/               # Scan results directory
    └── *.json                 # Scan result files
```

---

## 🔐 Security

### Authentication
- All dashboard endpoints require JWT authentication
- Token validated via `authenticate` middleware
- User must be logged in to access dashboard

### Authorization
- No role-based restrictions (all authenticated users can view)
- Future: Could add role checks for sensitive data

### Data Access
- Backend only reads from `./out` directory
- No user input in file paths (prevents directory traversal)
- JSON parsing wrapped in try-catch (prevents crashes)

---

## 🐛 Error Handling

### Frontend
- **No data**: Shows empty states with helpful messages
- **API errors**: React Query handles retries and error states
- **Chart errors**: Gracefully falls back to "No data available"

### Backend
- **Directory not found**: Returns empty array
- **File read errors**: Skips problematic files
- **JSON parse errors**: Skips invalid files
- **All errors**: Passed to Express error handler middleware

---

## 🎨 Color Scheme

### Severity Colors
```typescript
critical: '#ff4444'  // Red
high:     '#ff8800'  // Orange
medium:   '#ffbb33'  // Yellow
low:      '#00C851'  // Green
info:     '#33b5e5'  // Blue
```

### UI Colors
```typescript
primary:    '#E8500A'  // Orange (accent)
background: '#1A1A1A'  // Dark
surface:    '#242422'  // Elevated surface
text:       '#FFFFFF'  // Primary text
border:     '#2e2e2b'  // Border light
```

---

## 📊 Data Sources

### Primary Source
- **Location**: `./out/*.json` (backend directory)
- **Format**: AD Suite scan result JSON files
- **Structure**:
```json
{
  "meta": {
    "Timestamp": "2026-03-27T05:47:16Z",
    "checksRun": 661
  },
  "results": [
    {
      "CheckId": "ACC-001",
      "Severity": "high",
      "Category": "Access_Control",
      "FindingCount": 14
    }
  ]
}
```

### Fallback Data
- If no scans found: Returns default values
- `totalChecks: 775` (default catalog size)
- `severityData: all zeros`
- `categoryData: empty object`

---

## 🚀 Future Enhancements

### Planned Features
1. **Real-time Updates**: WebSocket integration for live scan progress
2. **Date Range Filter**: Filter statistics by time period
3. **Comparison View**: Compare current vs previous scans
4. **Export Dashboard**: Download dashboard as PDF/PNG
5. **Custom Widgets**: User-configurable dashboard layout
6. **Trend Lines**: Historical data visualization
7. **Risk Score**: Overall security posture score
8. **Alerts**: Configurable thresholds and notifications

---

## 📝 Summary

The Dashboard provides a comprehensive, real-time view of AD security posture through:
- **4 key metrics** (checks, findings, critical exposure, active scans)
- **2 interactive charts** (severity distribution, top categories)
- **Recent scan history** (last 10 scans with download)
- **Quick actions** (shortcuts to common tasks)

All data is fetched from the backend API, which reads and aggregates scan results from the `./out` directory. The UI is fully responsive, animated, and follows the orange/dark theme color scheme.

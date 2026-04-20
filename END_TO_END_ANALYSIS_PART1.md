# AD Suite - Complete End-to-End System Analysis
## Part 1: System Overview & Architecture

**Generated:** April 2, 2026  
**Purpose:** Comprehensive analysis of every component, data flow, webpage, graph, report, and interaction

---

## Table of Contents (Complete Document)

### Part 1: System Overview & Architecture
1. System Architecture Overview
2. Technology Stack Deep Dive
3. Data Flow Architecture
4. Component Interaction Map

### Part 2: Frontend Pages & User Flows
5. Login Page - Authentication Flow
6. Dashboard Page - Real-time Analytics
7. New Scan Page - Scan Configuration
8. Scans Page - Scan Management
9. Scan Detail Page - Results View
10. Analysis Page - Deep Findings Analysis

### Part 3: Advanced Features & Visualizations
11. Attack Path Page - AI-Powered Analysis
12. Reports Page - Export & Management
13. Terminal Page - Interactive PowerShell
14. Settings Page - Configuration

### Part 4: Backend Services & Data Processing
15. Backend API Architecture
16. WebSocket Services
17. PowerShell Scanning Engine
18. Database Schema & Operations

### Part 5: Data Flows & Integration
19. Complete Data Flow Diagrams
20. Graph Rendering Pipeline
21. Report Generation System
22. Real-time Communication

---

## 1. SYSTEM ARCHITECTURE OVERVIEW

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER BROWSER                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              React Frontend (Port 5173)                   │  │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ │  │
│  │  │Dashboard│ │ Scans  │ │Analysis│ │ Attack │ │Terminal│ │  │
│  │  │  Page  │ │  Page  │ │  Page  │ │  Path  │ │  Page  │ │  │
│  │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ │  │
│  │                                                            │  │
│  │  State Management: Zustand + React Query                  │  │
│  │  Visualization: Recharts, Sigma.js, D3, Cytoscape        │  │
│  │  Terminal: xterm.js with WebSocket                        │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTP/REST API (Port 3000)
                              │ WebSocket (Port 3001)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Node.js Backend Server                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Express API Server                       │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐           │  │
│  │  │Controllers │ │ Middleware │ │  Services  │           │  │
│  │  │  - Auth    │ │  - JWT     │ │  - Scan    │           │  │
│  │  │  - Scan    │ │  - OIDC    │ │  - Settings│           │  │
│  │  │  - Check   │ │  - Audit   │ │  - Report  │           │  │
│  │  └────────────┘ └────────────┘ └────────────┘           │  │
│  │                                                            │  │
│  │  WebSocket Servers:                                       │  │
│  │  - Terminal Server (node-pty)                            │  │
│  │  - Scan Progress Updates                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Spawn Process
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              PowerShell Scanning Engine                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         Invoke-ADSuiteScan.ps1                            │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐           │  │
│  │  │  LDAP/ADSI │ │   Modules  │ │  Catalogs  │           │  │
│  │  │   Queries  │ │  - Adsi    │ │  - checks  │           │  │
│  │  │            │ │  - Adcs    │ │  - overrides│           │  │
│  │  └────────────┘ └────────────┘ └────────────┘           │  │
│  │                                                            │  │
│  │  Output: JSON, CSV, HTML Reports                          │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ LDAP Protocol
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Active Directory Domain                         │
│  - Domain Controllers                                            │
│  - LDAP Services (Port 389/636)                                 │
│  - Kerberos (Port 88)                                           │
│  - Certificate Services (ADCS)                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Layers

**Layer 1: Presentation (Frontend)**
- React 18.2 with TypeScript
- Vite 5.0 for bundling
- Tailwind CSS for styling
- Component library: Custom + Lucide icons

**Layer 2: State Management**
- Zustand for global state
- React Query for server state
- IndexedDB for persistence
- Context API for settings

**Layer 3: Communication**
- Axios for HTTP requests
- WebSocket for real-time updates
- REST API endpoints
- JSON data format

**Layer 4: Business Logic (Backend)**
- Express.js server
- TypeScript controllers
- Service layer pattern
- Middleware chain

**Layer 5: Data Processing**
- PowerShell execution
- LDAP query engine
- JSON/CSV parsing
- Report generation

**Layer 6: Data Sources**
- Active Directory
- File system (uploads/)
- PostgreSQL (optional)
- Check catalogs (JSON)

---

## 2. TECHNOLOGY STACK DEEP DIVE

### 2.1 Frontend Technologies

#### React Components Architecture
```typescript
// Component Hierarchy
App.tsx
├── Layout.tsx (Navigation, Header, Footer)
│   ├── Dashboard.tsx
│   ├── NewScan.tsx
│   ├── Scans.tsx
│   │   └── ScanEntityGraph.tsx
│   ├── ScanDetail.tsx
│   ├── Analysis.tsx
│   ├── AttackPath.tsx
│   │   ├── AttackPathKillChainGraph.tsx
│   │   └── MermaidGraph (inline)
│   ├── Reports.tsx
│   │   └── FindingsPreview (inline)
│   ├── Terminal.tsx
│   └── Settings.tsx
└── Login.tsx (Standalone)
```

#### State Management Flow
```typescript
// Zustand Stores
authStore: {
  user: User | null
  token: string | null
  isAuthenticated: boolean
  login(user, token): void
  logout(): void
  checkAuth(): Promise<void>
}

useAppStore: {
  // Scan Management
  scans: Scan[]
  activeScanId: string | null
  scanHistory: ScanHistory[]
  
  // Configuration
  config: AppConfig
  
  // Actions
  addScan(scan): void
  updateScan(id, updates): void
  deleteScan(id): void
  setActiveScanId(id): void
  addScanHistory(entry): void
}

useFindingsStore: {
  // Findings by scan ID
  findingsByScan: Map<string, Finding[]>
  
  // Filters
  filters: {
    severity: Set<string>
    category: Set<string>
    search: string
  }
  
  // Actions
  setFindings(scanId, findings): void
  applyFilter(type, value): void
  clearFilters(): void
}
```


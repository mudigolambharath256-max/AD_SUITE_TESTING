# AD Suite Backend - Complete Documentation

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Technology Stack](#technology-stack)
4. [Applications Running](#applications-running)
5. [Required Dependencies](#required-dependencies)
6. [Directory Structure](#directory-structure)
7. [API Endpoints](#api-endpoints)
8. [Commands Reference](#commands-reference)
9. [Environment Configuration](#environment-configuration)
10. [How It Works](#how-it-works)

---

## Overview

The AD Suite backend is a **Node.js + Express** server written in **TypeScript** that provides:
- RESTful API for frontend communication
- WebSocket server for real-time scan updates
- PowerShell script execution for AD scanning
- File-based or PostgreSQL data storage
- Authentication and authorization
- Audit logging

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        FRONTEND                              │
│                   (React on port 5173)                       │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ HTTP/REST API
                 │ WebSocket
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                    BACKEND SERVER                            │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Express    │  │  WebSocket   │  │   node-pty   │     │
│  │   (HTTP)     │  │   Server     │  │ (PowerShell) │     │
│  │  Port 3000   │  │  Port 3001   │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Controllers & Services                   │  │
│  │  - Auth  - Scans  - Reports  - Analysis             │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└────────────┬────────────────────────────────┬───────────────┘
             │                                │
             │                                │
             ▼                                ▼
┌─────────────────────┐          ┌─────────────────────────┐
│   File Storage      │          │   PowerShell Engine     │
│   (uploads/)        │          │   (Invoke-ADSuiteScan)  │
│   - Scan results    │          │   - AD queries          │
│   - Analysis data   │          │   - Security checks     │
└─────────────────────┘          └─────────────────────────┘
             │
             ▼
┌─────────────────────┐
│  PostgreSQL (Opt)   │
│  Port 5432          │
└─────────────────────┘
```

---

## Technology Stack

### Core Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| **Node.js** | 18+ | JavaScript runtime |
| **TypeScript** | 5.3+ | Type-safe JavaScript |
| **Express.js** | 4.18+ | Web framework |
| **WebSocket (ws)** | 8.20+ | Real-time communication |
| **node-pty** | 1.1+ | PowerShell terminal emulation |

### Key Libraries

| Library | Purpose |
|---------|---------|
| **bcrypt** | Password hashing |
| **jsonwebtoken** | JWT authentication |
| **cors** | Cross-origin resource sharing |
| **helmet** | Security headers |
| **winston** | Logging |
| **multer** | File upload handling |
| **joi** | Input validation |
| **pg** | PostgreSQL client (optional) |
| **archiver** | ZIP file creation |
| **pdfkit** | PDF generation |
| **exceljs** | Excel export |

---

## Applications Running

When you start the backend with `npm run dev`, **THREE** separate applications/servers start:

### 1. **HTTP API Server** (Port 3000)

**What it does:**
- Handles all REST API requests from frontend
- Manages authentication and authorization
- Processes scan requests
- Serves file downloads
- Handles CRUD operations

**Key Features:**
- RESTful endpoints
- JWT-based authentication
- CORS enabled for frontend
- Request/response logging
- Error handling middleware

**Example Requests:**
```http
GET  /api/scans          # List all scans
POST /api/scans          # Create new scan
GET  /api/dashboard      # Dashboard metrics
POST /api/auth/login     # User login
```

### 2. **WebSocket Server** (Port 3001)

**What it does:**
- Provides real-time bidirectional communication
- Streams scan progress updates
- Sends terminal output in real-time
- Notifies frontend of events

**Key Features:**
- Real-time scan status updates
- Terminal command execution
- Live PowerShell output streaming
- Connection management

**Use Cases:**
- Scan progress bars
- Terminal page functionality
- Real-time notifications
- Live log streaming

### 3. **PowerShell Terminal Manager** (node-pty)

**What it does:**
- Spawns PowerShell processes
- Executes AD security scans
- Runs PowerShell commands
- Captures output in real-time

**Key Features:**
- Pseudo-terminal emulation
- ANSI color support
- Command history
- Process management

**Executes:**
```powershell
# Main scan script
.\Invoke-ADSuiteScan.ps1 -ChecksJson "checks.json" -OutputDir "out/"

# Terminal commands
Get-ADUser -Filter *
Test-Connection dc.domain.local
```

---

## Required Dependencies

### System Requirements

1. **Node.js 18+**
   ```bash
   node --version  # Should be v18.0.0 or higher
   ```

2. **npm** (comes with Node.js)
   ```bash
   npm --version
   ```

3. **PowerShell 5.1+ or PowerShell Core 7+**
   ```bash
   pwsh --version  # or powershell
   ```

4. **Windows OS** (for Active Directory scanning)

5. **Active Directory Access** (for running scans)

### Optional Dependencies

6. **PostgreSQL 14+** (if not using file-based storage)
   ```bash
   psql --version
   ```

7. **Git** (for version control)
   ```bash
   git --version
   ```

---

## Directory Structure

```
backend/
├── src/                          # TypeScript source code
│   ├── controllers/              # Request handlers
│   │   ├── authController.ts     # Authentication logic
│   │   ├── scanController.ts     # Scan management
│   │   ├── checkController.ts    # Security checks
│   │   ├── oidcController.ts     # OIDC authentication
│   │   └── ...
│   │
│   ├── routes/                   # API route definitions
│   │   ├── auth.ts               # /api/auth/*
│   │   ├── scans.ts              # /api/scans/*
│   │   ├── checks.ts             # /api/checks/*
│   │   ├── dashboard.ts          # /api/dashboard/*
│   │   ├── analysis.ts           # /api/analysis/*
│   │   ├── attackPath.ts         # /api/attack-path/*
│   │   ├── reports.ts            # /api/reports/*
│   │   └── settings.ts           # /api/settings/*
│   │
│   ├── middleware/               # Express middleware
│   │   ├── auth.ts               # JWT verification
│   │   ├── auditMiddleware.ts    # Audit logging
│   │   └── errorHandler.ts       # Error handling
│   │
│   ├── services/                 # Business logic
│   │   ├── scanService.ts        # Scan execution
│   │   └── settingsService.ts    # Settings management
│   │
│   ├── utils/                    # Utility functions
│   │   ├── logger.ts             # Winston logger
│   │   ├── auditLog.ts           # Audit trail
│   │   ├── validateEnv.ts        # Environment validation
│   │   ├── scanExportCsv.ts      # CSV export
│   │   ├── catalogPaths.ts       # Check catalog paths
│   │   ├── loadChecksCatalog.ts  # Load security checks
│   │   └── ...
│   │
│   ├── websocket/                # WebSocket logic
│   │   └── terminalServer.ts     # Terminal WebSocket
│   │
│   ├── server.ts                 # Main entry point
│   └── websocket.ts              # WebSocket setup
│
├── dist/                         # Compiled JavaScript (generated)
├── logs/                         # Application logs
│   ├── combined.log              # All logs
│   ├── error.log                 # Error logs only
│   └── audit.log                 # Audit trail
│
├── uploads/                      # File storage
│   └── analysis/                 # Scan results
│       └── *.json                # Scan result files
│
├── data/                         # Application data
│   └── settings.json             # App settings
│
├── node_modules/                 # Dependencies (generated)
├── package.json                  # Dependencies & scripts
├── tsconfig.json                 # TypeScript config
├── .env                          # Environment variables
└── .env.example                  # Environment template
```

---

## API Endpoints

### Authentication (`/api/auth`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/login` | User login |
| POST | `/api/auth/register` | User registration |
| POST | `/api/auth/logout` | User logout |
| GET | `/api/auth/me` | Get current user |

### Scans (`/api/scans`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/scans` | List all scans |
| GET | `/api/scans/:id` | Get scan details |
| POST | `/api/scans` | Create new scan |
| POST | `/api/scans/:id/execute` | Execute scan |
| POST | `/api/scans/:id/stop` | Stop running scan |
| DELETE | `/api/scans/:id` | Delete scan |
| GET | `/api/scans/:id/results` | Get scan results |
| GET | `/api/scans/:id/findings` | Get scan findings |
| GET | `/api/scans/:id/export/:format` | Export scan (json/csv/pdf) |

### Checks (`/api/checks`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/checks` | List all security checks |
| GET | `/api/checks/:id` | Get check details |
| GET | `/api/checks/categories` | Get check categories |

### Dashboard (`/api/dashboard`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dashboard/metrics` | Get dashboard metrics |
| GET | `/api/dashboard/recent-scans` | Get recent scans |
| GET | `/api/dashboard/severity-distribution` | Get severity stats |

### Analysis (`/api/analysis`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/analysis/upload` | Upload scan results |
| GET | `/api/analysis/:id` | Get analysis data |
| GET | `/api/analysis/:id/findings` | Get findings |

### Attack Path (`/api/attack-path`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/attack-path/analyze` | Analyze attack paths |
| GET | `/api/attack-path/:id` | Get attack path graph |

### Reports (`/api/reports`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/reports/generate` | Generate report |
| GET | `/api/reports/:id` | Download report |
| GET | `/api/reports` | List all reports |

### Settings (`/api/settings`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/settings` | Get all settings |
| PUT | `/api/settings` | Update settings |

---

## Commands Reference

### Development Commands

```bash
# Install dependencies
npm install

# Start development server (with hot reload)
npm run dev
# This runs: nodemon --exec ts-node src/server.ts
# - Watches for file changes
# - Automatically restarts server
# - Compiles TypeScript on-the-fly

# Build TypeScript to JavaScript
npm run build
# This runs: tsc
# - Compiles src/ to dist/
# - Generates .js and .js.map files
# - Type checks all code

# Start production server
npm start
# This runs: node dist/server.js
# - Runs compiled JavaScript
# - No hot reload
# - Production mode
```

### Testing & Quality

```bash
# Run tests
npm test
# This runs: jest

# Lint code
npm run lint
# This runs: eslint src/**/*.ts
# - Checks code style
# - Finds potential errors
```

### Manual Operations

```bash
# Check TypeScript errors
npx tsc --noEmit

# Format code
npx prettier --write "src/**/*.ts"

# Clean build
rm -rf dist/
npm run build
```

---

## Environment Configuration

### Required Variables

```env
# Server Configuration
NODE_ENV=development              # development | production
PORT=3000                         # HTTP API port
HOST=0.0.0.0                      # Listen on all interfaces

# JWT Authentication (REQUIRED)
JWT_SECRET=your_secret_key_min_32_chars  # Must be 32+ characters
JWT_EXPIRES_IN=7d                 # Token expiration

# Frontend URL (for CORS)
FRONTEND_URL=http://localhost:5173

# WebSocket
WS_PORT=3001                      # WebSocket server port

# PowerShell Scripts
PS_SCRIPT_PATH=../../Invoke-ADSuiteScan.ps1
PS_MODULE_PATH=../../Modules

# File Storage
UPLOAD_DIR=./uploads
MAX_FILE_SIZE=100MB

# Scan Settings
DEFAULT_SCAN_TIMEOUT=3600000      # 1 hour in milliseconds
MAX_CONCURRENT_SCANS=5
```

### Optional Variables

```env
# Database (Optional - uses file storage if not set)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=adsuite
DB_USER=postgres
DB_PASSWORD=your_password

# Email (Optional - for notifications)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASSWORD=your_app_password
EMAIL_FROM=AD Suite <noreply@adsuite.com>

# Checks Catalog
AD_SUITE_CHECKS_JSON=checks.json
CHECKS_JSON_PATH=checks.json
```

---

## How It Works

### 1. Server Startup Sequence

```typescript
// src/server.ts

1. Load environment variables (.env)
2. Validate required environment variables
3. Initialize Express app
4. Configure middleware:
   - helmet (security headers)
   - cors (cross-origin requests)
   - express.json (JSON parsing)
   - logging middleware
5. Register API routes
6. Setup error handling
7. Create HTTP server
8. Create WebSocket server (port 3001)
9. Initialize settings service
10. Start listening on port 3000
```

### 2. Request Flow

```
Client Request
    ↓
Express Middleware Stack
    ↓
1. Logging Middleware (logs request)
    ↓
2. CORS Middleware (checks origin)
    ↓
3. JSON Parser (parses body)
    ↓
4. Authentication Middleware (verifies JWT)
    ↓
5. Authorization Middleware (checks role)
    ↓
6. Audit Middleware (logs mutations)
    ↓
Route Handler (Controller)
    ↓
Service Layer (Business Logic)
    ↓
Data Layer (File/Database)
    ↓
Response
    ↓
Error Handler (if error occurs)
    ↓
Client Response
```

### 3. Scan Execution Flow

```
1. Frontend sends POST /api/scans/:id/execute
    ↓
2. scanController.executeScan()
    ↓
3. scanService.executeScan()
    ↓
4. Spawn PowerShell process (node-pty)
    ↓
5. Execute: Invoke-ADSuiteScan.ps1
    ↓
6. Stream output via WebSocket
    ↓
7. PowerShell queries Active Directory
    ↓
8. Generate findings JSON
    ↓
9. Save to uploads/analysis/
    ↓
10. Send completion via WebSocket
    ↓
11. Frontend displays results
```

### 4. WebSocket Communication

```typescript
// Client connects
ws://localhost:3001

// Server sends messages
{
  type: 'scan:progress',
  data: { scanId: '123', progress: 45, message: 'Checking users...' }
}

{
  type: 'scan:complete',
  data: { scanId: '123', resultsPath: '/uploads/analysis/scan-123.json' }
}

{
  type: 'terminal:output',
  data: { output: 'PS C:\\> Get-ADUser...' }
}
```

### 5. Authentication Flow

```
1. User submits login (POST /api/auth/login)
    ↓
2. authController.login()
    ↓
3. Validate credentials (bcrypt.compare)
    ↓
4. Generate JWT token (jsonwebtoken.sign)
    ↓
5. Return token to client
    ↓
6. Client stores token (localStorage)
    ↓
7. Client includes token in requests:
   Authorization: Bearer <token>
    ↓
8. auth middleware verifies token
    ↓
9. Request proceeds if valid
```

### 6. File Storage Structure

```
uploads/
└── analysis/
    ├── 1774958713799-random-goad-findings.json
    ├── 1774964649816-random-goad-findings.json
    └── 1775016235779-sample-goad-scan-results.json

Each file contains:
{
  "scanId": "1774958713799",
  "timestamp": "2026-04-11T10:30:00Z",
  "findings": [...],
  "metadata": {...},
  "graph": {...}
}
```

---

## Process Management

### What Runs When You Start Backend

```bash
npm run dev
```

**Spawns:**

1. **Main Node.js Process**
   - PID: e.g., 12345
   - Runs: nodemon
   - Watches: src/**/*.ts

2. **Child Process: ts-node**
   - PID: e.g., 12346
   - Runs: src/server.ts
   - Compiles TypeScript

3. **HTTP Server Thread**
   - Port: 3000
   - Handles: REST API

4. **WebSocket Server Thread**
   - Port: 3001
   - Handles: Real-time communication

5. **PowerShell Processes (on-demand)**
   - Spawned when: Scan executed or terminal used
   - Managed by: node-pty
   - Lifecycle: Created → Execute → Terminate

### Stopping the Backend

```bash
# Graceful shutdown
Ctrl + C

# Force kill (if needed)
# Windows
taskkill /F /PID <PID>

# Find process by port
netstat -ano | findstr :3000
```

---

## Logging

### Log Files

```
logs/
├── combined.log    # All logs (info, warn, error)
├── error.log       # Errors only
└── audit.log       # Audit trail (who did what)
```

### Log Levels

```typescript
logger.error('Critical error')   // Errors
logger.warn('Warning message')   // Warnings
logger.info('Info message')      // General info
logger.debug('Debug details')    // Debug (dev only)
```

### Example Logs

```
2026-04-11T10:30:00.000Z [info]: 🚀 HTTP API listening on http://0.0.0.0:3000
2026-04-11T10:30:00.001Z [info]: 📡 WebSocket server running on port 3001
2026-04-11T10:30:00.002Z [info]: 🌍 Environment: development
2026-04-11T10:35:15.123Z [info]: POST /api/scans
2026-04-11T10:35:20.456Z [info]: Scan 1774958713799 started
2026-04-11T10:40:30.789Z [info]: Scan 1774958713799 completed
```

---

## Security Features

1. **Helmet** - Security headers
2. **CORS** - Cross-origin protection
3. **JWT** - Token-based authentication
4. **bcrypt** - Password hashing
5. **Rate Limiting** - API throttling
6. **Input Validation** - Joi schemas
7. **Audit Logging** - Action tracking
8. **Error Sanitization** - No sensitive data in errors

---

## Performance Considerations

- **Concurrent Scans**: Limited to 5 by default
- **File Upload**: Max 100MB
- **Request Timeout**: 1 hour for scans
- **WebSocket**: Persistent connections
- **Logging**: Async file writes
- **JSON Parsing**: 32MB limit for attack-path

---

## Troubleshooting

### Backend Won't Start

```bash
# Check Node.js version
node --version  # Must be 18+

# Check if ports are free
netstat -ano | findstr :3000
netstat -ano | findstr :3001

# Check environment variables
cat .env

# Check logs
cat logs/error.log
```

### Scan Execution Fails

```bash
# Check PowerShell
pwsh --version

# Test PowerShell script manually
pwsh -File ../../Invoke-ADSuiteScan.ps1 -ChecksJson "checks.json"

# Check script path in .env
echo $PS_SCRIPT_PATH
```

### WebSocket Connection Issues

```bash
# Check if WebSocket server is running
netstat -ano | findstr :3001

# Check CORS settings
echo $FRONTEND_URL

# Check browser console for errors
```

---

## Summary

The AD Suite backend is a **multi-threaded Node.js application** that:

✅ Runs **3 concurrent servers** (HTTP, WebSocket, PowerShell manager)  
✅ Provides **RESTful API** for frontend communication  
✅ Executes **PowerShell scans** against Active Directory  
✅ Streams **real-time updates** via WebSocket  
✅ Stores **scan results** in files or PostgreSQL  
✅ Implements **JWT authentication** and audit logging  
✅ Supports **multiple export formats** (JSON, CSV, PDF)  

**Key Commands:**
- `npm install` - Install dependencies
- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm start` - Run production server

**Ports Used:**
- **3000** - HTTP API
- **3001** - WebSocket
- **5432** - PostgreSQL (optional)

---

**Version:** 1.0.7  
**Last Updated:** April 2026

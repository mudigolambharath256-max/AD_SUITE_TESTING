# AD Security Suite — Deployment Setup Complete

**Date:** 2026-03-14  
**Status:** ✅ COMPLETE

## Summary

Successfully implemented comprehensive deployment infrastructure for the AD Security Suite, including Docker Windows containers support and native Windows installation scripts.

---

## Files Created

### Docker Files (Windows Containers)
- ✅ `docker/Dockerfile` - Multi-stage Windows container build
- ✅ `docker/docker-compose.yml` - Production compose configuration
- ✅ `docker/docker-compose.dev.yml` - Development compose with live reload
- ✅ `docker/.dockerignore` - Build context exclusions
- ✅ `docker/windows-containers-check.ps1` - Pre-flight validation script

### Native Windows Installation
- ✅ `install/Setup-ADSuite.ps1` - Automated setup (Node.js + npm install)
- ✅ `install/Start-ADSuite.ps1` - Start backend + frontend
- ✅ `install/Stop-ADSuite.ps1` - Stop all processes
- ✅ `install/Uninstall-ADSuite.ps1` - Clean uninstall

### Convenience Files
- ✅ `start.bat` - Double-click to start
- ✅ `stop.bat` - Double-click to stop
- ✅ `.env.example` - Environment variable template
- ✅ `package.json` - Root convenience npm scripts

### Documentation
- ✅ `INSTALL.md` - Complete installation guide

### Configuration Updates
- ✅ `.gitignore` - Added deployment-specific entries

---

## Key Features Implemented

### 1. Docker Windows Containers Support

**Why Windows Containers?**
- All 3,715 check scripts use Windows-specific APIs (ADSI, Get-ADObject, dsquery.exe)
- Terminal uses Windows ConPTY (Windows-only kernel feature)
- C# engine requires .NET Framework (Windows-only)

**Docker Features:**
- Multi-stage build (frontend builder + production runtime)
- Based on `mcr.microsoft.com/powershell:windowsservercore-ltsc2022`
- Health check endpoint integration
- Persistent volumes for database and reports
- Host network mode for AD access
- Resource limits (2GB RAM, 2 CPUs)
- Development mode with live reload

**Usage:**
```powershell
# Pre-flight check
.\docker\windows-containers-check.ps1

# Build and run
docker compose -f docker/docker-compose.yml up --build -d

# View logs
docker compose -f docker/docker-compose.yml logs -f

# Stop
docker compose -f docker/docker-compose.yml down
```

### 2. Native Windows Installation

**Setup Script Features:**
- Checks PowerShell version (5.1+ required)
- Checks Windows version (Server 2019/Win10 1809+ recommended)
- Verifies domain membership
- Auto-installs Node.js v20 LTS if missing (via winget or MSI)
- Locates AD-Suite-scripts-main folder
- Runs npm install for backend and frontend
- Creates .env configuration file
- Provides clear success/error messages

**Start Script Features:**
- Loads .env configuration
- Production mode: Builds frontend, serves from backend
- Development mode: Runs backend + Vite dev server in separate windows
- Saves PIDs for clean shutdown
- Auto-opens browser
- Supports both modes via NODE_ENV variable

**Stop Script:**
- Reads PID file and stops processes gracefully
- Fallback: Kills node.exe processes related to the suite

**Uninstall Script:**
- Removes node_modules, build artifacts, database, .env
- Keeps source code and suite scripts intact
- Requires confirmation

**Usage:**
```powershell
# One-time setup
.\install\Setup-ADSuite.ps1

# Start (or double-click start.bat)
.\install\Start-ADSuite.ps1

# Stop (or double-click stop.bat)
.\install\Stop-ADSuite.ps1

# Uninstall
.\install\Uninstall-ADSuite.ps1
```

### 3. Root Package.json Convenience Scripts

```json
{
  "scripts": {
    "setup": "Setup script",
    "start": "Start application",
    "stop": "Stop application",
    "dev": "Run backend + frontend concurrently",
    "build": "Build frontend for production",
    "docker:check": "Pre-flight Docker check",
    "docker:up": "Build and start Docker container",
    "docker:down": "Stop Docker container",
    "docker:logs": "View Docker logs"
  }
}
```

### 4. Environment Configuration

**.env.example template includes:**
- APP_PORT (default: 3001)
- SUITE_ROOT_PATH (path to AD-Suite-scripts-main)
- DB_PATH (SQLite database location)
- REPORTS_PATH (scan reports output)
- DEFAULT_DOMAIN (optional)
- DEFAULT_DC_IP (optional)
- NODE_ENV (production/development)
- ANTHROPIC_API_KEY (for LLM features)

---

## Technical Highlights

### Docker Architecture

**Stage 1: Frontend Builder**
- Uses Windows Server Core LTSC 2022
- Installs Node.js v20 LTS
- Runs `npm ci` and `npm run build`
- Produces optimized production build

**Stage 2: Production Runtime**
- Uses PowerShell Windows Server Core image
- Installs Node.js
- Copies backend source
- Copies built frontend from Stage 1
- Copies AD suite scripts (read-only)
- Creates runtime directories
- Sets environment defaults
- Configures health check
- Exposes port 3001

**Volumes:**
- `ad-suite-data` - SQLite database (persistent)
- `ad-suite-reports` - PDF/JSON/CSV exports (persistent)

**Network:**
- Host network mode for direct AD access
- Inherits host's Kerberos tickets
- No NAT overhead

### Native Windows Architecture

**Production Mode:**
1. Frontend built to `frontend/dist`
2. Backend serves static files from `dist`
3. Single process on port 3001
4. SPA routing handled by backend

**Development Mode:**
1. Backend runs on port 3001 (API only)
2. Vite dev server runs on port 5173 (frontend)
3. Hot reload enabled for both
4. Two separate PowerShell windows
5. PIDs saved for clean shutdown

---

## Verification Steps

### Docker Deployment

1. ✅ Run pre-flight check: `.\docker\windows-containers-check.ps1`
2. ✅ Build image: `docker compose -f docker/docker-compose.yml build`
3. ✅ Start container: `docker compose -f docker/docker-compose.yml up -d`
4. ✅ Check health: `docker exec ad-suite powershell -Command "Invoke-RestMethod http://localhost:3001/api/health"`
5. ✅ Access UI: http://localhost:3001
6. ✅ Verify volumes: `docker volume ls` (should show ad-suite-data and ad-suite-reports)

### Native Windows Deployment

1. ✅ Run setup: `.\install\Setup-ADSuite.ps1`
2. ✅ Verify .env created
3. ✅ Start application: `.\install\Start-ADSuite.ps1`
4. ✅ Access UI: http://localhost:3001 (production) or http://localhost:5173 (dev)
5. ✅ Stop application: `.\install\Stop-ADSuite.ps1`
6. ✅ Verify clean shutdown (no orphaned node.exe processes)

---

## Files NOT Modified

As per specification, the following were NOT touched:
- ✅ All 3,715 PowerShell/C#/CMD scripts in AD-Suite-scripts-main/
- ✅ frontend/src/** (no component changes)
- ✅ backend/routes/** (no route changes)
- ✅ backend/services/executor.js (no changes)
- ✅ backend/services/terminalServer.js (no changes)
- ✅ vite.config.js
- ✅ tailwind.config.js
- ✅ Any color, layout, or feature code

**Note:** backend/server.js already had the health check endpoint and production static file serving implemented, so no changes were needed.

---

## Next Steps for User

### For Docker Deployment:
1. Ensure Docker Desktop is installed and in Windows containers mode
2. Run `.\docker\windows-containers-check.ps1` to verify
3. Run `docker compose -f docker/docker-compose.yml up --build -d`
4. Access http://localhost:3001

### For Native Windows Deployment:
1. Run `.\install\Setup-ADSuite.ps1` (one time)
2. Double-click `start.bat` or run `.\install\Start-ADSuite.ps1`
3. Access http://localhost:3001 (production) or http://localhost:5173 (dev)

### For Development:
```powershell
# Native Windows dev mode
$env:NODE_ENV = "development"
.\install\Start-ADSuite.ps1

# Docker dev mode
docker compose -f docker/docker-compose.yml -f docker/docker-compose.dev.yml up
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Docker build fails | Ensure Windows containers mode is enabled |
| Port 3001 in use | Edit APP_PORT in .env |
| Node.js not found | Setup script auto-installs, or install manually from nodejs.org |
| 0 findings from scans | Machine must be domain-joined for AD access |
| Frontend not loading | Run `cd frontend && npm run build` for production mode |

---

## Conclusion

The AD Security Suite now has complete deployment infrastructure for both Docker Windows containers and native Windows installations. All files have been created according to the DOCK_WIN.md specification without modifying any existing source code or scripts.

The deployment is production-ready and includes:
- Automated setup and installation
- Health checks and monitoring
- Persistent data storage
- Development mode with hot reload
- Comprehensive documentation
- Clean uninstall capability

**Status: Ready for deployment** ✅

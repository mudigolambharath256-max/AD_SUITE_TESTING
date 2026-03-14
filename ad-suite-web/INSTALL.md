# AD Security Suite — Installation Guide

## Requirements

- Windows 10/11 or Windows Server 2019/2022
- Domain-joined machine (required for AD script execution)
- Current domain user with AD read permissions
- Internet access for first-time setup (downloads Node.js if missing)

---

## Method 1 — Native Windows (Recommended)

### Step 1: Clone the repository
```powershell
git clone https://github.com/your-org/ad-security-suite.git
cd ad-security-suite
```

### Step 2: Run setup (one time only)
```powershell
powershell -ExecutionPolicy Bypass -File install\Setup-ADSuite.ps1
```

This installs Node.js (if missing), runs npm install for backend and
frontend, and creates a `.env` configuration file.

### Step 3: Configure (optional)
Edit `.env` in the project root:
```
DEFAULT_DOMAIN=your.domain.local
DEFAULT_DC_IP=192.168.1.10
```

### Step 4: Start the application
```
Double-click start.bat
```
Or from PowerShell:
```powershell
.\install\Start-ADSuite.ps1
```

The browser opens automatically at **http://localhost:3001**

### Step 5: Configure suite path (first run)
1. Go to **Settings**
2. Set Suite Root Path to the `AD-Suite-scripts-main` folder
3. Click **Validate** — should show 775 checks

### Stop the application
```
Double-click stop.bat
```

---

## Method 2 — Docker (Windows Containers)

> **Requires:** Docker Desktop for Windows with Windows containers mode enabled.
> Right-click the Docker Desktop tray icon → **Switch to Windows containers**

### Step 1: Verify Docker is ready
```powershell
powershell -ExecutionPolicy Bypass -File docker\windows-containers-check.ps1
```
All checks must pass before proceeding.

### Step 2: Clone and build
```powershell
git clone https://github.com/your-org/ad-security-suite.git
cd ad-security-suite
docker compose -f docker/docker-compose.yml up --build -d
```
The first build takes 5-10 minutes (downloads Windows base image ~4GB).

### Step 3: Open the application
```
http://localhost:3001
```

### Step 4: Configure suite path in Settings
Suite path inside the container: `C:\app\AD-Suite-scripts-main`

### Useful Docker commands
```powershell
# View logs
docker compose -f docker/docker-compose.yml logs -f

# Stop
docker compose -f docker/docker-compose.yml down

# Rebuild after code changes
docker compose -f docker/docker-compose.yml up --build -d

# Enter the container for debugging
docker exec -it ad-suite powershell
```

### Data persistence
The database and scan reports are stored in Docker named volumes:
- `ad-suite-data`    → SQLite database
- `ad-suite-reports` → PDF/JSON/CSV exports

These persist across container restarts. To reset:
```powershell
docker compose -f docker/docker-compose.yml down -v
```

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| 0 findings from scans | Machine not domain-joined | Join machine to target AD domain |
| 0 findings from scans | Wrong suite path | Settings → set correct path → Validate |
| PowerShell error on scan | Execution policy | Setup script sets -ExecutionPolicy Bypass |
| Port 3001 already in use | Another process | Edit APP_PORT in .env |
| Docker build fails | Linux containers mode | Switch to Windows containers in Docker Desktop |
| Docker scripts return empty | Container network | Ensure network_mode: host in docker-compose.yml |

---

## Development Mode

For development with hot reload:

```powershell
# Native Windows
$env:NODE_ENV = "development"
.\install\Start-ADSuite.ps1

# Docker
docker compose -f docker/docker-compose.yml -f docker/docker-compose.dev.yml up
```

This starts:
- Backend at http://localhost:3001/api
- Frontend at http://localhost:5173 (with Vite hot reload)

---

## Uninstall

```powershell
.\install\Uninstall-ADSuite.ps1
```

This removes node_modules, build artifacts, database, and .env but keeps source code intact.

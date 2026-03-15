# Setup Guide After Git Clone

## Complete Setup Instructions Using NPM Commands

### Step 1: Clone the Repository

```bash
git clone https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
cd AD_SUITE_TESTING
```

---

### Step 2: Navigate to the Web Application Folder

```bash
cd ad-suite-web
```

---

### Step 3: Install Backend Dependencies

```bash
# Navigate to backend folder
cd backend

# Install all backend dependencies
npm install

# Go back to ad-suite-web root
cd ..
```

**What this installs:**
- Express.js (web server)
- SQLite3 (database)
- node-pty (terminal emulation)
- Other backend dependencies

---

### Step 4: Install Frontend Dependencies

```bash
# Navigate to frontend folder
cd frontend

# Install all frontend dependencies
npm install

# Go back to ad-suite-web root
cd ..
```

**What this installs:**
- React (UI framework)
- Vite (build tool)
- Tailwind CSS (styling)
- D3.js (graph visualization)
- Other frontend dependencies

---

### Step 5: Create Environment Configuration

```bash
# Copy the example environment file
copy .env.example .env

# Or on PowerShell:
Copy-Item .env.example .env
```

**Edit the .env file** with your settings:
```env
APP_PORT=3001
NODE_ENV=development
SUITE_ROOT_PATH=C:\path\to\AD_SUITE_TESTING
DB_PATH=.\backend\database.db
REPORTS_PATH=.\backend\reports
DEFAULT_DOMAIN=
DEFAULT_DC_IP=
ANTHROPIC_API_KEY=
```

---

### Step 6: Build the Frontend (Production)

```bash
# Navigate to frontend folder
cd frontend

# Build the production bundle
npm run build

# Go back to ad-suite-web root
cd ..
```

This creates the `frontend/dist` folder with optimized production files.

---

### Step 7: Start the Application

#### Option A: Production Mode (Recommended)

```bash
# From ad-suite-web root
cd backend
node server.js
```

The backend will serve the built frontend from `frontend/dist`.

#### Option B: Development Mode (with Hot Reload)

**Terminal 1 - Backend:**
```bash
cd backend
npm run dev
# or
node server.js
```

**Terminal 2 - Frontend:**
```bash
cd frontend
npm run dev
```

Access the app:
- Production: http://localhost:3001
- Development: http://localhost:5173 (frontend) + http://localhost:3001 (backend API)

---

### Step 8: Verify Installation

Open your browser and navigate to:
```
http://localhost:3001
```

You should see the AD Security Suite dashboard.

---

## NPM Scripts Reference

### Backend Scripts (in `backend/package.json`)

```bash
# Start the backend server
npm start

# Start with nodemon (auto-restart on changes)
npm run dev

# Run tests (if available)
npm test
```

### Frontend Scripts (in `frontend/package.json`)

```bash
# Start development server with hot reload
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Lint code
npm run lint
```

---

## Complete Setup Commands (Copy-Paste)

### For PowerShell:

```powershell
# Clone and navigate
git clone https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
cd AD_SUITE_TESTING\ad-suite-web

# Install backend dependencies
cd backend
npm install
cd ..

# Install frontend dependencies
cd frontend
npm install
cd ..

# Create .env file
Copy-Item .env.example .env

# Build frontend
cd frontend
npm run build
cd ..

# Start the application
cd backend
node server.js
```

### For CMD/Bash:

```bash
# Clone and navigate
git clone https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
cd AD_SUITE_TESTING/ad-suite-web

# Install backend dependencies
cd backend
npm install
cd ..

# Install frontend dependencies
cd frontend
npm install
cd ..

# Create .env file
cp .env.example .env

# Build frontend
cd frontend
npm run build
cd ..

# Start the application
cd backend
node server.js
```

---

## Troubleshooting

### Issue: `npm: command not found`

**Solution:** Install Node.js from https://nodejs.org (LTS version recommended)

```bash
# Verify installation
node --version
npm --version
```

---

### Issue: `EACCES` permission errors

**Solution:** Run as administrator or fix npm permissions

```bash
# Windows: Run PowerShell as Administrator
# Then run npm install again
```

---

### Issue: Port 3001 already in use

**Solution:** Kill the process or change the port

```bash
# Find process using port 3001
netstat -ano | findstr :3001

# Kill the process (Windows)
taskkill /PID <PID> /F

# Or change port in .env file
APP_PORT=3002
```

---

### Issue: `Cannot find module` errors

**Solution:** Clear cache and reinstall

```bash
# Delete node_modules and package-lock.json
rm -rf node_modules package-lock.json

# Reinstall
npm install
```

---

### Issue: Frontend build fails

**Solution:** Check Node.js version and clear cache

```bash
# Ensure Node.js 18+ is installed
node --version

# Clear npm cache
npm cache clean --force

# Reinstall and rebuild
cd frontend
rm -rf node_modules package-lock.json
npm install
npm run build
```

---

## Quick Start Script

Save this as `quick-setup.ps1` in the ad-suite-web folder:

```powershell
# Quick Setup Script
Write-Host "=== AD Security Suite - Quick Setup ===" -ForegroundColor Cyan

# Install backend
Write-Host "`nInstalling backend dependencies..." -ForegroundColor Yellow
cd backend
npm install
cd ..

# Install frontend
Write-Host "`nInstalling frontend dependencies..." -ForegroundColor Yellow
cd frontend
npm install
cd ..

# Create .env
if (-not (Test-Path .env)) {
    Write-Host "`nCreating .env file..." -ForegroundColor Yellow
    Copy-Item .env.example .env
}

# Build frontend
Write-Host "`nBuilding frontend..." -ForegroundColor Yellow
cd frontend
npm run build
cd ..

Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green
Write-Host "To start the application, run:" -ForegroundColor White
Write-Host "  cd backend" -ForegroundColor Cyan
Write-Host "  node server.js" -ForegroundColor Cyan
Write-Host "`nThen open: http://localhost:3001" -ForegroundColor White
```

Run it with:
```powershell
.\quick-setup.ps1
```

---

## Development Workflow

### Making Changes to Frontend

```bash
# Start dev server with hot reload
cd frontend
npm run dev

# Make your changes in src/
# Browser will auto-refresh

# When done, build for production
npm run build
```

### Making Changes to Backend

```bash
# Start with nodemon for auto-restart
cd backend
npm run dev

# Make your changes in backend files
# Server will auto-restart
```

---

## Package.json Scripts Explained

### Backend (`backend/package.json`)

```json
{
  "scripts": {
    "start": "node server.js",           // Start production server
    "dev": "nodemon server.js",          // Start with auto-restart
    "test": "jest"                       // Run tests
  }
}
```

### Frontend (`frontend/package.json`)

```json
{
  "scripts": {
    "dev": "vite",                       // Start dev server (port 5173)
    "build": "vite build",               // Build for production
    "preview": "vite preview",           // Preview production build
    "lint": "eslint . --ext js,jsx"     // Check code quality
  }
}
```

---

## Next Steps After Setup

1. **Configure the Suite Path**: Edit `.env` and set `SUITE_ROOT_PATH` to your AD scripts location
2. **Test a Scan**: Run a test scan from the web interface
3. **Check Terminal**: Test the integrated terminal feature
4. **Review Documentation**: Check the other .md files for detailed features

---

## Need Help?

- Check `README.md` for detailed documentation
- Review `HOW_TO_RUN.md` for running individual scripts
- See `DOCK_WIN.md` for Docker deployment
- Check the GitHub repository for issues and updates

---

**Pro Tip**: Use `npm ci` instead of `npm install` for faster, more reliable installs in CI/CD environments!

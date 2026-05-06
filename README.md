# AD Suite - Active Directory Security Assessment Platform

Enterprise-grade Active Directory security assessment platform with 756 automated security checks and modern web interface.

## 🚀 Quick Start

### Prerequisites

- **Node.js** 18+ and npm
- **PowerShell** 5.1+ or PowerShell Core 7+
- **Git**
- **Windows** operating system (for AD scanning)
- **Active Directory** access (for running scans)

### Installation Steps

#### 1. Clone the Repository

```bash
git clone https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
cd AD_SUITE_TESTING
```

#### 2. Install Dependencies

**Option A: Install Both (Recommended for Development)**

```bash
# Navigate to AD-Suite-Web directory
cd AD-Suite-Web

# Install dependencies for both frontend and backend
npm install

# This installs:
# - concurrently (to run both servers together)
# - All backend dependencies
# - All frontend dependencies
```

**Option B: Install Separately**

```bash
# Backend
cd AD-Suite-Web/backend
npm install

# Frontend (in a new terminal)
cd AD-Suite-Web/frontend
npm install
```

#### 3. Configure Environment Variables

**Backend Configuration:**

```bash
# Navigate to backend directory
cd AD-Suite-Web/backend

# Copy environment template
copy .env.example .env

# Edit .env file with your settings
notepad .env
```

**Required Configuration in `.env`:**

```env
# JWT Authentication (IMPORTANT: Change this!)
JWT_SECRET=your_secure_secret_key_at_least_32_characters_long_change_this_in_production

# Server Configuration
NODE_ENV=development
PORT=3000
HOST=0.0.0.0

# Frontend URL (for CORS)
FRONTEND_URL=http://localhost:5173

# WebSocket
WS_PORT=3001

# PowerShell Scripts (relative to backend directory)
PS_SCRIPT_PATH=../../Invoke-ADSuiteScan.ps1
PS_MODULE_PATH=../../Modules
```

**Frontend Configuration (Optional):**

```bash
cd AD-Suite-Web/frontend
copy .env.example .env
```

The frontend uses Vite proxy by default, so no configuration is usually needed.

#### 4. Start the Application

**Option A: Run Both Together (Easiest)**

```bash
# From AD-Suite-Web directory
cd AD-Suite-Web
npm run dev
```

This starts both backend and frontend simultaneously with colored output:
- 🔵 **Backend (api):** http://localhost:3000 + ws://localhost:3001
- 🟢 **Frontend (web):** http://localhost:5173

**Option B: Run Separately**

**Terminal 1 - Backend:**
```bash
cd AD-Suite-Web/backend
npm run dev
```

**Terminal 2 - Frontend:**
```bash
cd AD-Suite-Web/frontend
npm run dev
```

#### 5. Access the Application

Open your browser and navigate to:
```
http://localhost:5173
```

**First Time Setup:**
- The application will load the web interface
- Navigate to "New Scan" to configure and run your first scan
- Check "Settings" to configure scan preferences

**Note:** Authentication is optional. Check backend configuration if login is required.

---

## 📋 Available Commands

### Run Both Frontend & Backend Together

```bash
cd AD-Suite-Web

# Development mode (runs both servers)
npm run dev

# This is equivalent to running:
# - Backend: npm run dev --prefix backend
# - Frontend: npm run dev --prefix frontend
```

### Backend Commands

```bash
cd AD-Suite-Web/backend

# Development mode (with hot reload)
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

### Frontend Commands

```bash
cd AD-Suite-Web/frontend

# Development mode (with hot reload)
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

---

## 🔧 Configuration

### Backend Configuration (.env)

Key environment variables to configure:

```env
# Server
NODE_ENV=development
PORT=3000
HOST=0.0.0.0

# JWT Authentication
JWT_SECRET=your_secure_secret_key_at_least_32_characters_long
JWT_EXPIRES_IN=7d

# Frontend URL (for CORS)
FRONTEND_URL=http://localhost:5173

# Database (Optional - uses file-based storage by default)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=adsuite
DB_USER=postgres
DB_PASSWORD=your_password

# PowerShell Scripts
PS_SCRIPT_PATH=../../Invoke-ADSuiteScan.ps1
PS_MODULE_PATH=../../Modules

# WebSocket
WS_PORT=3001
```

### Frontend Configuration (.env)

```env
# API URL (optional - uses Vite proxy by default)
# VITE_API_URL=http://localhost:3000/api

# WebSocket URL (optional)
# VITE_WS_URL=ws://localhost:3001
```

---

## 🐳 Docker Deployment (Optional)

For production deployment using Docker:

```bash
# Navigate to the web directory
cd AD-Suite-Web

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

Services will be available at:
- **Frontend:** http://localhost:80
- **Backend API:** http://localhost:3000
- **PostgreSQL:** localhost:5432

---

## 🔍 Running Your First Scan

1. **Access the Web UI:** http://localhost:5173
2. **Navigate to:** New Scan page
3. **Configure Scan:**
   - Enter scan name
   - Select security check categories
   - Choose specific checks (optional)
4. **Run Scan:** Click "Run Scan" button
5. **View Results:** Results appear automatically after completion

---

## 📊 Key Features

- **756 Security Checks** across multiple categories
- **Real-time Scan Execution** with WebSocket updates
- **Interactive Graph Visualization** for attack paths
- **Comprehensive Dashboard** with metrics and charts
- **Multiple Export Formats** (JSON, CSV, PDF, HTML)
- **PowerShell Terminal** for advanced operations
- **Automated Reporting** and compliance support

---

## 🗂️ Project Structure

```
AD_SUITE_TESTING/
├── AD-Suite-Web/           # Web application
│   ├── backend/            # Node.js + Express API
│   │   ├── src/            # TypeScript source code
│   │   ├── dist/           # Compiled JavaScript
│   │   └── uploads/        # Scan results storage
│   ├── frontend/           # React + TypeScript UI
│   │   ├── src/            # Source code
│   │   └── dist/           # Production build
│   └── database/           # PostgreSQL schema
├── Modules/                # PowerShell modules
├── engines/                # Scan engines (ADSI, RSAT, C#)
├── checks.json             # Security check catalog
├── Invoke-ADSuiteScan.ps1  # Main scan script
└── README.md               # This file
```

---

## 🛠️ Troubleshooting

### "npm install" Fails

**Issue:** Dependencies fail to install

**Solution:**
```bash
# Clear npm cache
npm cache clean --force

# Delete node_modules and package-lock.json
rm -rf node_modules package-lock.json

# Reinstall
npm install
```

### Port Already in Use

**Issue:** Ports 3000, 3001, or 5173 are already in use

**Solution (Windows):**
```powershell
# Find process using port 3000
netstat -ano | findstr :3000

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F
```

**Solution (Linux/Mac):**
```bash
# Find and kill process on port 3000
lsof -ti:3000 | xargs kill -9
```

### Backend Won't Start

**Common Issues:**

1. **Node.js version too old**
   ```bash
   node --version  # Should be 18.0.0 or higher
   ```

2. **Missing .env file**
   ```bash
   cd AD-Suite-Web/backend
   copy .env.example .env
   ```

3. **JWT_SECRET not configured**
   - Open `.env` file
   - Set `JWT_SECRET` to at least 32 characters

4. **Check logs**
   ```bash
   # Logs are created in AD-Suite-Web/backend/logs/
   cat AD-Suite-Web/backend/logs/error.log
   ```

### Frontend Won't Connect to Backend

**Common Issues:**

1. **Backend not running**
   - Verify backend is running: http://localhost:3000/api/health
   - Check terminal for backend errors

2. **CORS errors**
   - Verify `FRONTEND_URL=http://localhost:5173` in backend `.env`
   - Restart backend after changing `.env`

3. **Browser cache**
   ```
   - Press Ctrl+Shift+R (hard refresh)
   - Or clear browser cache
   ```

4. **Check browser console**
   - Press F12 to open developer tools
   - Look for errors in Console tab

### PowerShell Scan Errors

**Common Issues:**

1. **PowerShell version**
   ```powershell
   $PSVersionTable.PSVersion  # Should be 5.1 or higher
   ```

2. **Execution policy**
   ```powershell
   # Run PowerShell as Administrator
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Active Directory module missing**
   ```powershell
   # Install RSAT tools (Windows 10/11)
   Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
   ```

4. **Script path incorrect**
   - Verify `PS_SCRIPT_PATH` in backend `.env`
   - Default: `../../Invoke-ADSuiteScan.ps1`

### "concurrently" Command Not Found

**Issue:** Running `npm run dev` from AD-Suite-Web fails

**Solution:**
```bash
cd AD-Suite-Web
npm install concurrently --save-dev
```

### Build Errors

**Issue:** `npm run build` fails

**Solution:**
```bash
# Backend
cd AD-Suite-Web/backend
rm -rf dist node_modules
npm install
npm run build

# Frontend
cd AD-Suite-Web/frontend
rm -rf dist node_modules
npm install
npm run build
```

---

## 📖 Documentation

- **Backend Documentation:** [AD-Suite-Web/BACKEND_DOCUMENTATION.md](AD-Suite-Web/BACKEND_DOCUMENTATION.md)
- **Cleanup Summary:** [CLEANUP_SUMMARY.md](CLEANUP_SUMMARY.md)
- **Technical Docs:** See `docs/` folder for detailed documentation

---

## 🔐 Security Considerations

- **Change default JWT_SECRET** in production
- **Use HTTPS** for production deployments
- **Restrict network access** to backend API
- **Enable authentication** for production use
- **Regular security updates** for dependencies
- **Secure credential storage** for AD access

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📝 License

This project is proprietary software. All rights reserved.

---

## 📞 Support

For issues, questions, or support:
- **GitHub Issues:** https://github.com/mudigolambharath256-max/AD_SUITE_TESTING/issues
- **Documentation:** See docs folder

---

## 🎯 Quick Command Reference

### Complete Setup (First Time)

```bash
# 1. Clone repository
git clone https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
cd AD_SUITE_TESTING

# 2. Install all dependencies
cd AD-Suite-Web
npm install

# 3. Configure backend
cd backend
copy .env.example .env
notepad .env  # Edit JWT_SECRET and other settings

# 4. Start both servers
cd ..
npm run dev

# 5. Open browser
# Navigate to: http://localhost:5173
```

### Daily Development Workflow

```bash
# Start both frontend and backend
cd AD-Suite-Web
npm run dev

# Access application at: http://localhost:5173
```

### Production Build

```bash
# Build backend
cd AD-Suite-Web/backend
npm run build
npm start

# Build frontend (in new terminal)
cd AD-Suite-Web/frontend
npm run build
npm run preview
```

### Useful Commands

```bash
# Check if servers are running
curl http://localhost:3000/api/health  # Backend health check
curl http://localhost:5173             # Frontend

# View backend logs
cat AD-Suite-Web/backend/logs/combined.log

# Clean and reinstall
cd AD-Suite-Web/backend
rm -rf node_modules package-lock.json
npm install

cd ../frontend
rm -rf node_modules package-lock.json
npm install
```

---

## 📦 What Gets Installed

After running `npm install`, you'll have:

**AD-Suite-Web/backend/node_modules/** (~200MB)
- Express, TypeScript, WebSocket libraries
- PowerShell integration (node-pty)
- Authentication and security packages

**AD-Suite-Web/frontend/node_modules/** (~300MB)
- React, TypeScript, Vite
- UI libraries (Tailwind, Lucide icons)
- Graph visualization (Cytoscape)

**Note:** `node_modules` folders are NOT committed to git. They're generated locally when you run `npm install`.

---

**Version:** 1.0.8  
**Last Updated:** May 6, 2026  
**Status:** ✅ Production Ready

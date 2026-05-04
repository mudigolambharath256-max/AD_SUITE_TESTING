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

#### 2. Backend Setup

```bash
# Navigate to backend directory
cd AD-Suite-Web/backend

# Install dependencies
npm install

# Copy environment file
copy .env.example .env

# Edit .env file and configure:
# - JWT_SECRET (use at least 32 characters)
# - Database credentials (if using PostgreSQL)
# - SMTP settings (if using email notifications)
# - FRONTEND_URL (default: http://localhost:5173)

# Build the backend
npm run build

# Start the backend server
npm run dev
```

The backend will start on:
- **HTTP API:** http://localhost:3000
- **WebSocket:** ws://localhost:3001

#### 3. Frontend Setup

Open a **new terminal** and run:

```bash
# Navigate to frontend directory
cd AD-Suite-Web/frontend

# Install dependencies
npm install

# Copy environment file (optional)
copy .env.example .env

# Start the frontend development server
npm run dev
```

The frontend will start on:
- **Web UI:** http://localhost:5173

#### 4. Access the Application

Open your browser and navigate to:
```
http://localhost:5173
```

Default login (if authentication is enabled):
- Username: `admin`
- Password: Check backend configuration

---

## 📋 Available Commands

### Backend Commands

```bash
cd AD-Suite-Web/backend

# Development mode (with hot reload)
npm run dev

# Build for production
npm run build

# Start production server
npm start

# Run tests
npm test

# Lint code
npm run lint
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

# Lint code
npm run lint
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

### Port Already in Use

If ports 3000, 3001, or 5173 are already in use:

**Windows:**
```powershell
# Find process using port 3000
netstat -ano | findstr :3000

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F
```

### Backend Won't Start

1. Check if Node.js 18+ is installed: `node --version`
2. Verify `.env` file exists and is configured
3. Ensure JWT_SECRET is at least 32 characters
4. Check logs in `AD-Suite-Web/backend/logs/`

### Frontend Won't Connect to Backend

1. Verify backend is running on port 3000
2. Check CORS settings in backend `.env` (FRONTEND_URL)
3. Clear browser cache and reload
4. Check browser console for errors

### PowerShell Scan Errors

1. Ensure PowerShell 5.1+ is installed
2. Run PowerShell as Administrator
3. Check Active Directory connectivity
4. Verify `Invoke-ADSuiteScan.ps1` path in backend `.env`

---

## 📖 Documentation

- **Project Overview:** [AD-Suite-Web/PROJECT_OVERVIEW.md](AD-Suite-Web/PROJECT_OVERVIEW.md)
- **Quick Reference:** [AD-Suite-Web/QUICK_REFERENCE.md](AD-Suite-Web/QUICK_REFERENCE.md)
- **Dashboard Guide:** [AD-Suite-Web/DASHBOARD_DOCUMENTATION.md](AD-Suite-Web/DASHBOARD_DOCUMENTATION.md)
- **System Flow:** [COMPLETE_SYSTEM_FLOW_DOCUMENTATION.md](COMPLETE_SYSTEM_FLOW_DOCUMENTATION.md)

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

### Start Everything (Development)

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

**Access:** http://localhost:5173

### Production Build

```bash
# Build backend
cd AD-Suite-Web/backend
npm run build
npm start

# Build frontend
cd AD-Suite-Web/frontend
npm run build
npm run preview
```

---

**Version:** 1.0.7  
**Last Updated:** April 2026  
**Status:** ✅ Production Ready

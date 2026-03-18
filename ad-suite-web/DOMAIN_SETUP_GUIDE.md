# AD Suite - Domain-Joined Machine Setup Guide

## Problem
When accessing the AD Suite website from a domain-joined machine, the PowerShell scripts execute on the host machine (where the web server runs) instead of on the domain-joined machine that has Active Directory access.

## Solution
Run the backend server on the domain-joined machine and configure the frontend to connect to it.

---

## Setup Instructions

### Option 1: Backend on Domain-Joined Machine (Recommended)

This is the proper architecture - the backend runs on the machine with AD access.

#### Step 1: On the Domain-Joined Machine

1. **Clone the repository:**
   ```bash
   git clone -b development https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
   cd AD_SUITE_TESTING
   ```

2. **Install Node.js** (if not already installed)
   - Download from: https://nodejs.org/
   - Recommended: LTS version

3. **Install backend dependencies:**
   ```bash
   cd ad-suite-web/backend
   npm install
   ```

4. **Configure the Suite Root Path:**
   - Edit `ad-suite-web/backend/server.js` or use the Settings page
   - Set the path to your AD security checks folder

5. **Start the backend server:**
   ```bash
   npm start
   ```
   
   The backend will start on port 3001. Note the IP address shown (e.g., `http://192.168.1.100:3001`)

6. **Allow firewall access:**
   ```powershell
   # Run as Administrator
   New-NetFirewallRule -DisplayName "AD Suite Backend" -Direction Inbound -LocalPort 3001 -Protocol TCP -Action Allow
   ```

#### Step 2: On Your Host Machine (where you access the website)

1. **Update the frontend configuration:**
   
   Edit `ad-suite-web/frontend/.env`:
   ```env
   VITE_BACKEND_URL=http://192.168.1.100:3001
   ```
   Replace `192.168.1.100` with the actual IP address of your domain-joined machine.

2. **Restart the frontend server:**
   ```bash
   cd ad-suite-web/frontend
   npm run dev
   ```

3. **Access the website:**
   - Open browser: http://localhost:5173/
   - Or from another machine: http://YOUR_HOST_IP:5173/

Now when you run scans, they will execute on the domain-joined machine!

---

### Option 2: Both Frontend and Backend on Domain-Joined Machine

Run everything on the domain-joined machine:

1. **On the domain-joined machine:**
   ```bash
   # Clone repository
   git clone -b development https://github.com/mudigolambharath256-max/AD_SUITE_TESTING.git
   cd AD_SUITE_TESTING
   
   # Install backend dependencies
   cd ad-suite-web/backend
   npm install
   npm start
   
   # In another terminal, install frontend dependencies
   cd ad-suite-web/frontend
   npm install
   npm run dev
   ```

2. **Allow firewall access:**
   ```powershell
   # Run as Administrator
   New-NetFirewallRule -DisplayName "AD Suite Frontend" -Direction Inbound -LocalPort 5173 -Protocol TCP -Action Allow
   New-NetFirewallRule -DisplayName "AD Suite Backend" -Direction Inbound -LocalPort 3001 -Protocol TCP -Action Allow
   ```

3. **Access from any machine on the network:**
   - http://DOMAIN_MACHINE_IP:5173/

---

## Verification

1. **Check backend is running on domain-joined machine:**
   - Open browser on domain-joined machine: http://localhost:3001/api/health
   - Should return: `{"status":"ok"}`

2. **Check frontend can connect to backend:**
   - Open the website
   - Go to Settings page
   - Validate the Suite Root Path
   - Run a test scan

3. **Verify scripts execute on domain-joined machine:**
   - Run a scan from the website
   - Check the backend terminal on the domain-joined machine
   - You should see scan execution logs

---

## Troubleshooting

### Frontend can't connect to backend
- Check firewall rules on domain-joined machine
- Verify the IP address in `.env` is correct
- Test backend directly: http://DOMAIN_MACHINE_IP:3001/api/health

### Scripts still run on wrong machine
- Verify you're accessing the correct frontend URL
- Check the Network tab in browser DevTools to see where API requests go
- Restart both frontend and backend after configuration changes

### Permission errors when running scans
- Ensure the user running the backend has appropriate AD permissions
- Run PowerShell as Administrator if needed
- Check the Suite Root Path points to the correct location

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Network                              │
│                                                              │
│  ┌──────────────────┐                ┌──────────────────┐  │
│  │  Host Machine    │                │ Domain-Joined    │  │
│  │                  │                │ Machine          │  │
│  │  Frontend        │───────────────▶│  Backend         │  │
│  │  (Port 5173)     │   API Calls    │  (Port 3001)     │  │
│  │                  │                │                  │  │
│  │  Browser Access  │                │  Executes        │  │
│  │  ◄───────────    │                │  PowerShell      │  │
│  │                  │                │  Scripts         │  │
│  └──────────────────┘                │                  │  │
│                                      │  ▼               │  │
│                                      │  Active          │  │
│                                      │  Directory       │  │
│                                      └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Production Deployment

For production use:

1. **Build the frontend:**
   ```bash
   cd ad-suite-web/frontend
   npm run build
   ```

2. **Serve the built files:**
   - Use IIS, nginx, or Apache to serve the `dist` folder
   - Configure reverse proxy to backend API

3. **Run backend as a service:**
   - Use PM2, Windows Service, or Task Scheduler
   - Ensure it starts automatically on boot

4. **Security considerations:**
   - Use HTTPS with proper certificates
   - Implement authentication/authorization
   - Restrict network access with firewall rules
   - Use environment variables for sensitive configuration

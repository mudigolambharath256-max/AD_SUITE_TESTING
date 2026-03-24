# Network Access Fix for Run Scans Page

## Problem
The Run Scans page was showing blank when accessed from a network-connected machine (192.168.56.10:5173) but worked fine on localhost.

## Root Cause
The Vite development server proxy was configured to forward API requests to `localhost:3001`, which works fine when accessing from the host machine but fails when accessing from a network machine because:

1. Browser on network machine loads the page from `192.168.56.10:5173`
2. Page tries to make API calls to `/api/*` endpoints
3. Vite proxy forwards these to `localhost:3001` (which is localhost on the CLIENT machine, not the server)
4. API calls fail silently, causing the page to appear blank

## Solution
Updated `ad-suite-web/frontend/.env` to use the actual server IP address:

```env
VITE_BACKEND_URL=http://192.168.56.10:3001
```

## Steps to Apply Fix

1. **Stop the frontend development server** (if running)
   - Press `Ctrl+C` in the terminal running the frontend

2. **Restart the frontend server**
   ```bash
   cd ad-suite-web/frontend
   npm run dev
   ```

3. **Verify the fix**
   - Access from network machine: `http://192.168.56.10:5173/scans`
   - The page should now load properly with all functionality

## Alternative: Dynamic Backend URL

If you need to access from both localhost AND network machines, you can use this approach:

### Option 1: Use the backend's network endpoint for both
```env
VITE_BACKEND_URL=http://192.168.56.10:3001
```
This works for both localhost and network access.

### Option 2: Build for production
For production deployment, build the frontend and serve it from the backend:

```bash
cd ad-suite-web/frontend
npm run build
```

Then access via: `http://192.168.56.10:3001` (backend serves the built frontend)

## Notes
- Environment variables in Vite (prefixed with `VITE_`) are embedded at build time
- Changes to `.env` require restarting the dev server
- For production, always use the actual server IP or domain name, not localhost

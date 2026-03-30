# Technieum AD suite (web)

Web UI for the Technieum AD suite security assessment stack: JWT auth, file-backed scan results (under the repo `out/` tree and uploads), reports, and real-time scan progress over WebSockets.

## What runs where

| Service | Default | Notes |
|--------|---------|--------|
| Frontend (Vite) | `http://localhost:5173` | Proxies `/api` and `/health` to the backend in dev |
| Backend (Express) | `http://localhost:3000` | REST API under `/api`, health at `/health` |
| WebSocket | `ws://localhost:3001` | Scan status stream (`VITE_WS_URL`) |

Scans are executed by `Invoke-ADSuiteScan.ps1` at the **AD_SUITE repository root** (sibling paths to `AD-Suite-Web`). Output is written to `out/scan-<id>/` with `scan-results.json` and optional `scan.meta.json`.

## Prerequisites

- Node.js 18+
- Windows with **PowerShell 5.1+** for live scans (same machine as the domain tools, when applicable)
- Optional: PostgreSQL only if you enable features that use it; the file-backed scan flow does not require it

## Setup

```bash
cd AD-Suite-Web

# Backend
cd backend
cp .env.example .env
# Set JWT_SECRET to at least 32 characters for production
npm install

# Frontend
cd ../frontend
cp .env.example .env
npm install
```

### Environment (backend)

- **JWT_SECRET** — signing key; must be **≥ 32 characters** in production (enforced at startup).
- **AD_SUITE_CHECKS_JSON** or **CHECKS_JSON_PATH** — path to `checks.json` (repo-relative or absolute). Defaults to `checks.json` at repo root.
- **WS_PORT** — WebSocket server port (default `3001`).
- **FRONTEND_URL** — allowed origin for CORS (e.g. `http://localhost:5173`).

### Environment (frontend)

- **VITE_API_URL** — API base (e.g. `http://localhost:3000/api`).
- **VITE_BACKEND_ORIGIN** — optional; backend origin for `/health` and non-proxied calls (no trailing slash).
- **VITE_WS_URL** — WebSocket URL for scan updates.

## Run (development)

**Recommended — one terminal (API + Vite):**

```bash
cd AD-Suite-Web
npm install
npm run dev
```

Then open **`http://localhost:5173`** in the browser (the web UI). The API alone on port 3000 does not serve the React app; if you open `http://localhost:3000/api` or `/health` you will only see JSON.

**Or — two terminals:**

Terminal 1 — backend:

```bash
cd AD-Suite-Web/backend
npm run dev
```

Terminal 2 — frontend:

```bash
cd AD-Suite-Web/frontend
npm run dev
```

Sign in via `POST /api/auth/login` (demo user is defined in `authController` when using the seed path). The UI stores the JWT in `localStorage` and sends `Authorization: Bearer` on API calls.

## Build

```bash
cd AD-Suite-Web/backend && npm run build
cd ../frontend && npm run build
```

## API

OpenAPI (if enabled): `http://localhost:3000/api/docs`

## License

MIT

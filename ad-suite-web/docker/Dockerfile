# ────────────────────────────────────────────────────────────────────────────
# AD Security Suite — Windows Container
# Base: Windows Server Core + PowerShell
# Requires: Docker Desktop for Windows with Windows containers mode
#           The host machine must be domain-joined for AD script execution
# ────────────────────────────────────────────────────────────────────────────

# Stage 1: Build the React frontend
# Using a Windows base so we stay on one platform throughout
FROM mcr.microsoft.com/windows/servercore:ltsc2022 AS frontend-builder

# Install Node.js (LTS) silently
SHELL ["powershell", "-ExecutionPolicy", "Bypass", "-Command"]

RUN Invoke-WebRequest -Uri "https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi" `
    -OutFile "C:\\node-installer.msi"; `
    Start-Process msiexec.exe -Wait -ArgumentList '/I C:\\node-installer.msi /quiet /norestart'; `
    Remove-Item C:\\node-installer.msi

# Add node and npm to PATH
RUN $env:PATH = $env:PATH + ';C:\\Program Files\\nodejs'; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, 'Machine')

WORKDIR C:\\app

# Copy and build frontend
COPY ad-suite-web/frontend/package.json ad-suite-web/frontend/package-lock.json* ./frontend/
RUN cd frontend; npm ci --prefer-offline

COPY ad-suite-web/frontend/ ./frontend/
RUN cd frontend; npm run build

# ────────────────────────────────────────────────────────────────────────────
# Stage 2: Production runtime image
# Uses the PowerShell image which includes PowerShell 7 + .NET
# PowerShell 7 is compatible with the ADSI scripts
# ────────────────────────────────────────────────────────────────────────────
FROM mcr.microsoft.com/powershell:windowsservercore-ltsc2022

SHELL ["powershell", "-ExecutionPolicy", "Bypass", "-Command"]

# Install Node.js
RUN Invoke-WebRequest -Uri "https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi" `
    -OutFile "C:\\node-installer.msi"; `
    Start-Process msiexec.exe -Wait -ArgumentList '/I C:\\node-installer.msi /quiet /norestart'; `
    Remove-Item C:\\node-installer.msi

# Update PATH for the session
RUN $env:PATH = $env:PATH + ';C:\\Program Files\\nodejs'; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, 'Machine')

WORKDIR C:\\app

# ── Install backend dependencies ─────────────────────────────────────────
COPY ad-suite-web/backend/package.json ad-suite-web/backend/package-lock.json* ./backend/
RUN cd backend; npm ci --prefer-offline --omit=dev; `
    Write-Host "Backend dependencies installed"

# ── Copy backend source ───────────────────────────────────────────────────
COPY ad-suite-web/backend/ ./backend/

# ── Copy built frontend from Stage 1 ─────────────────────────────────────
# The backend serves the frontend dist as static files
COPY --from=frontend-builder C:/app/frontend/dist ./backend/public

# ── Copy the AD suite scripts ─────────────────────────────────────────────
# The checks are read-only — never modify these in the container
# Copy all category folders from the root (Access_Control, Authentication, etc.)
COPY Access_Control/ ./AD-Suite-scripts-main/Access_Control/
COPY Advanced_Security/ ./AD-Suite-scripts-main/Advanced_Security/
COPY Authentication/ ./AD-Suite-scripts-main/Authentication/
COPY Azure_AD_Integration/ ./AD-Suite-scripts-main/Azure_AD_Integration/
COPY Backup_Recovery/ ./AD-Suite-scripts-main/Backup_Recovery/
COPY Certificate_Services/ ./AD-Suite-scripts-main/Certificate_Services/
COPY Compliance/ ./AD-Suite-scripts-main/Compliance/
COPY Computer_Management/ ./AD-Suite-scripts-main/Computer_Management/
COPY Computers_Servers/ ./AD-Suite-scripts-main/Computers_Servers/
COPY Domain_Configuration/ ./AD-Suite-scripts-main/Domain_Configuration/
COPY Domain_Controllers/ ./AD-Suite-scripts-main/Domain_Controllers/
COPY Group_Policy/ ./AD-Suite-scripts-main/Group_Policy/
COPY Infrastructure/ ./AD-Suite-scripts-main/Infrastructure/
COPY Kerberos_Security/ ./AD-Suite-scripts-main/Kerberos_Security/
COPY LDAP_Security/ ./AD-Suite-scripts-main/LDAP_Security/
COPY Network_Security/ ./AD-Suite-scripts-main/Network_Security/
COPY Persistence_Detection/ ./AD-Suite-scripts-main/Persistence_Detection/
COPY PKI_Services/ ./AD-Suite-scripts-main/PKI_Services/
COPY Privileged_Access/ ./AD-Suite-scripts-main/Privileged_Access/
COPY Published_Resources/ ./AD-Suite-scripts-main/Published_Resources/
COPY Security_Accounts/ ./AD-Suite-scripts-main/Security_Accounts/
COPY Service_Accounts/ ./AD-Suite-scripts-main/Service_Accounts/
COPY SMB_Security/ ./AD-Suite-scripts-main/SMB_Security/
COPY Trust_Management/ ./AD-Suite-scripts-main/Trust_Management/
COPY Trust_Relationships/ ./AD-Suite-scripts-main/Trust_Relationships/
COPY Users_Accounts/ ./AD-Suite-scripts-main/Users_Accounts/

# ── Create runtime directories ────────────────────────────────────────────
RUN New-Item -ItemType Directory -Force -Path C:\app\data | Out-Null; `
    New-Item -ItemType Directory -Force -Path C:\app\reports | Out-Null

# ── Environment defaults (override via docker-compose or .env) ───────────
ENV NODE_ENV=production
ENV PORT=3001
ENV SUITE_ROOT_PATH=C:\app\AD-Suite-scripts-main
ENV DB_PATH=C:\app\data\database.db
ENV REPORTS_PATH=C:\app\reports

# ── Health check ──────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 `
    CMD powershell -Command "try { Invoke-RestMethod http://localhost:3001/api/health -TimeoutSec 5; exit 0 } catch { exit 1 }"

# ── Expose port ───────────────────────────────────────────────────────────
EXPOSE 3001

# ── Start the backend (which also serves the built frontend) ─────────────
CMD ["node", "C:\\app\\backend\\server.js"]

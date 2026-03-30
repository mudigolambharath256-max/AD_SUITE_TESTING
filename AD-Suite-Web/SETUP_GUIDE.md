# AD Suite Web Platform - Setup Guide

## Complete Installation Guide

### Prerequisites

- **Node.js** 18+ ([Download](https://nodejs.org/))
- **PostgreSQL** 14+ ([Download](https://www.postgresql.org/download/))
- **PowerShell** 5.1+ (Windows built-in)
- **Git** ([Download](https://git-scm.com/))

### Step 1: Clone Repository

```bash
git clone https://github.com/robert-technieum-offsec/AD-SUITE.git
cd AD-SUITE/AD-Suite-Web
```

### Step 2: Database Setup

```bash
# Start PostgreSQL service (Windows)
# Services -> PostgreSQL -> Start

# Create database
psql -U postgres
CREATE DATABASE adsuite;
\q

# Run schema
psql -U postgres -d adsuite -f database/schema.sql
```

### Step 3: Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your settings (database password, JWT secret, etc.)

# Build TypeScript
npm run build

# Start development server
npm run dev
```

Backend will run on: `http://localhost:3000`

### Step 4: Frontend Setup

```bash
cd ../frontend

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env if needed (default settings work for local development)

# Start development server
npm run dev
```

Frontend will run on: `http://localhost:5173`

### Step 5: Access Application

1. Open browser: `http://localhost:5173`
2. Login with demo credentials:
   - Email: `admin@example.com`
   - Password: `password123`

## Docker Setup (Alternative)

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

Access at: `http://localhost`

## Production Deployment

### Build Frontend

```bash
cd frontend
npm run build
# Output in: dist/
```

### Build Backend

```bash
cd backend
npm run build
# Output in: dist/
```

### Environment Variables (Production)

```bash
# Backend .env
NODE_ENV=production
PORT=3000
DB_HOST=your-db-host
DB_PASSWORD=strong-password
JWT_SECRET=strong-random-secret
FRONTEND_URL=https://your-domain.com
```

### Nginx Configuration

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # Frontend
    location / {
        root /var/www/adsuite/frontend/dist;
        try_files $uri $uri/ /index.html;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # WebSocket
    location /ws {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
    }
}
```

## Features Overview

### 1. Authentication & Authorization
- JWT-based authentication
- Role-based access control (Admin, Analyst, Viewer)
- Multi-tenant organization support

### 2. Scan Management
- Create and configure scans
- Real-time scan execution monitoring
- Historical scan tracking
- Scheduled scans (cron-based)

### 3. Dashboard & Analytics
- Real-time statistics
- Risk score trends
- Category breakdown
- Top findings

### 4. Findings Management
- Filter by severity, category
- Remediation tracking
- Team collaboration (comments)
- Status workflow (Open → In Progress → Resolved)

### 5. Reporting
- PDF report generation
- Excel export
- Custom report templates
- Email notifications

### 6. Real-time Updates
- WebSocket-based live updates
- Scan progress monitoring
- Instant notifications

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Get current user
- `POST /api/auth/logout` - Logout

### Scans
- `GET /api/scans` - List scans
- `POST /api/scans` - Create scan
- `GET /api/scans/:id` - Get scan details
- `POST /api/scans/:id/execute` - Execute scan
- `POST /api/scans/:id/stop` - Stop scan
- `GET /api/scans/:id/results` - Get results
- `GET /api/scans/:id/export/:format` - Export (json/csv/pdf/excel)

### Dashboard
- `GET /api/dashboard/stats` - Get statistics
- `GET /api/dashboard/trends` - Get trend data

### Users (Admin only)
- `GET /api/users` - List users
- `POST /api/users` - Create user
- `PUT /api/users/:id` - Update user
- `DELETE /api/users/:id` - Delete user

## Development

### Backend Development

```bash
cd backend
npm run dev  # Auto-reload on changes
npm run lint # Check code quality
npm test     # Run tests
```

### Frontend Development

```bash
cd frontend
npm run dev  # Auto-reload on changes
npm run lint # Check code quality
npm run build # Production build
```

### Database Migrations

```bash
# Add new migration
psql -U postgres -d adsuite -f database/migrations/001_add_feature.sql
```

## Troubleshooting

### Backend won't start
- Check PostgreSQL is running
- Verify database credentials in `.env`
- Check port 3000 is not in use

### Frontend won't connect to backend
- Verify backend is running on port 3000
- Check `VITE_API_URL` in frontend `.env`
- Check CORS settings in backend

### Scans not executing
- Verify PowerShell script paths in backend `.env`
- Check `PS_SCRIPT_PATH` points to `Invoke-ADSuiteScan.ps1`
- Ensure PowerShell execution policy allows scripts

### Database connection errors
- Verify PostgreSQL service is running
- Check database credentials
- Ensure database `adsuite` exists

## Security Considerations

1. **Change default credentials** in production
2. **Use strong JWT secret** (32+ random characters)
3. **Enable HTTPS** in production
4. **Set up firewall rules** for database
5. **Regular security updates** for dependencies
6. **Implement rate limiting** for API endpoints
7. **Enable audit logging** for compliance

## Support

For issues or questions:
- GitHub Issues: https://github.com/robert-technieum-offsec/AD-SUITE/issues
- Documentation: See README.md files in each directory

## License

MIT License - See LICENSE file for details

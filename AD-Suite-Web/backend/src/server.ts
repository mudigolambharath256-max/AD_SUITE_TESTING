import express, { Application } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import { logger } from './utils/logger';
import { validateEnv } from './utils/validateEnv';
import { errorHandler } from './middleware/errorHandler';
import { setupWebSocket } from './websocket';
import { settingsService } from './services/settingsService';

// Routes
import authRoutes from './routes/auth';
import scanRoutes from './routes/scans';
import checkRoutes from './routes/checks';
import reportRoutes from './routes/reports';
import userRoutes from './routes/users';
import dashboardRoutes from './routes/dashboard';
import analysisRoutes from './routes/analysis';
import settingsRoutes from './routes/settings';
import attackPathRoutes from './routes/attackPath';

dotenv.config();

const app: Application = express();
const PORT = process.env.PORT || 3000;
const WS_PORT = process.env.WS_PORT || 3001;

// Middleware
app.use(helmet());
app.use(cors({
    origin: process.env.FRONTEND_URL || 'http://localhost:5173',
    credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging
app.use((req, res, next) => {
    logger.info(`${req.method} ${req.path}`);
    next();
});

// Root: in dev, many users open :3000 expecting the UI — point them at Vite
app.get('/', (req, res) => {
    if (process.env.NODE_ENV !== 'production') {
        return res.status(200).json({
            message: 'Technieum AD suite API (Express). The web UI is served by Vite in development.',
            webUi: process.env.FRONTEND_URL || 'http://localhost:5173',
            health: '/health',
            api: '/api'
        });
    }
    res.status(404).json({ message: 'Not found' });
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString(), version: '1.0.0' });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/scans', scanRoutes);
app.use('/api/checks', checkRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/users', userRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/analysis', analysisRoutes);
app.use('/api/settings', settingsRoutes);
app.use('/api/attack-path', attackPathRoutes);

// API Documentation
app.get('/api/docs', (req, res) => {
    res.json({
        version: '1.0.0',
        endpoints: {
            auth: '/api/auth',
            scans: '/api/scans',
            checks: '/api/checks',
            reports: '/api/reports',
            users: '/api/users',
            dashboard: '/api/dashboard'
        }
    });
});

// Error handling
app.use(errorHandler);

// HTTP Server
const server = createServer(app);

// WebSocket Server
const wss = new WebSocketServer({ port: Number(WS_PORT) });
setupWebSocket(wss);

async function bootstrap() {
    try {
        validateEnv();
        await settingsService.initialize();
    } catch (e) {
        logger.error(`Startup failed: ${e}`);
        process.exit(1);
    }

    server.listen(PORT, () => {
        logger.info(`🚀 Server running on port ${PORT}`);
        logger.info(`📡 WebSocket server running on port ${WS_PORT}`);
        logger.info(`🌍 Environment: ${process.env.NODE_ENV}`);
    });
}

bootstrap();

// Graceful shutdown
process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down gracefully');
    server.close(() => {
        logger.info('Server closed');
        process.exit(0);
    });
});

export default app;



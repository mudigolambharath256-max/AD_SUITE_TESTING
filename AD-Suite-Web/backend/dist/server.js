"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const dotenv_1 = __importDefault(require("dotenv"));
const http_1 = require("http");
const ws_1 = require("ws");
const logger_1 = require("./utils/logger");
const validateEnv_1 = require("./utils/validateEnv");
const errorHandler_1 = require("./middleware/errorHandler");
const websocket_1 = require("./websocket");
const settingsService_1 = require("./services/settingsService");
// Routes
const auth_1 = __importDefault(require("./routes/auth"));
const scans_1 = __importDefault(require("./routes/scans"));
const checks_1 = __importDefault(require("./routes/checks"));
const reports_1 = __importDefault(require("./routes/reports"));
const users_1 = __importDefault(require("./routes/users"));
const dashboard_1 = __importDefault(require("./routes/dashboard"));
const analysis_1 = __importDefault(require("./routes/analysis"));
const settings_1 = __importDefault(require("./routes/settings"));
const attackPath_1 = __importDefault(require("./routes/attackPath"));
const oidcAuth_1 = __importDefault(require("./routes/oidcAuth"));
dotenv_1.default.config();
const app = (0, express_1.default)();
const PORT = process.env.PORT || 3000;
const WS_PORT = process.env.WS_PORT || 3001;
/** Comma-separated browser origins allowed for CORS (e.g. LAN: http://192.168.1.10:5173,http://host.domain.local:5173). */
const corsOrigins = (process.env.FRONTEND_URL || 'http://localhost:5173')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
// Middleware
app.use((0, helmet_1.default)());
app.use((0, cors_1.default)({
    origin: (origin, callback) => {
        if (!origin) {
            callback(null, true);
            return;
        }
        if (corsOrigins.includes(origin)) {
            callback(null, true);
            return;
        }
        logger_1.logger.warn(`CORS blocked for origin: ${origin} (set FRONTEND_URL to include this origin)`);
        callback(null, false);
    },
    credentials: true
}));
/** Large scan flatten payloads exceed the default ~100kb JSON limit and caused 500 on POST /api/attack-path/analyze */
const ATTACK_PATH_JSON_LIMIT = process.env.ATTACK_PATH_JSON_LIMIT || '32mb';
const DEFAULT_JSON_LIMIT = process.env.JSON_BODY_LIMIT || '2mb';
app.use('/api/attack-path', express_1.default.json({ limit: ATTACK_PATH_JSON_LIMIT }), attackPath_1.default);
app.use(express_1.default.json({ limit: DEFAULT_JSON_LIMIT }));
app.use(express_1.default.urlencoded({ extended: true, limit: DEFAULT_JSON_LIMIT }));
// Request logging
app.use((req, res, next) => {
    logger_1.logger.info(`${req.method} ${req.path}`);
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
app.use('/api/auth', auth_1.default);
app.use('/api/auth/oidc', oidcAuth_1.default);
app.use('/api/scans', scans_1.default);
app.use('/api/checks', checks_1.default);
app.use('/api/reports', reports_1.default);
app.use('/api/users', users_1.default);
app.use('/api/dashboard', dashboard_1.default);
app.use('/api/analysis', analysis_1.default);
app.use('/api/settings', settings_1.default);
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
app.use(errorHandler_1.errorHandler);
// HTTP Server
const server = (0, http_1.createServer)(app);
// WebSocket Server
const wss = new ws_1.WebSocketServer({ port: Number(WS_PORT) });
(0, websocket_1.setupWebSocket)(wss);
async function bootstrap() {
    try {
        (0, validateEnv_1.validateEnv)();
        await settingsService_1.settingsService.initialize();
    }
    catch (e) {
        logger_1.logger.error(`Startup failed: ${e}`);
        process.exit(1);
    }
    const listenHost = process.env.HOST || '0.0.0.0';
    server.listen(Number(PORT), listenHost, () => {
        logger_1.logger.info(`🚀 HTTP API listening on http://${listenHost}:${PORT}`);
        logger_1.logger.info(`📡 WebSocket server running on port ${WS_PORT} (all interfaces)`);
        logger_1.logger.info(`🌍 Environment: ${process.env.NODE_ENV}`);
    });
}
bootstrap();
// Graceful shutdown
process.on('SIGTERM', () => {
    logger_1.logger.info('SIGTERM received, shutting down gracefully');
    server.close(() => {
        logger_1.logger.info('Server closed');
        process.exit(0);
    });
});
exports.default = app;
//# sourceMappingURL=server.js.map
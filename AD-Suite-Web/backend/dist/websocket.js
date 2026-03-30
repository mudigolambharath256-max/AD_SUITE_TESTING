"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.setupWebSocket = setupWebSocket;
exports.broadcastScanUpdate = broadcastScanUpdate;
exports.sendToUser = sendToUser;
const ws_1 = require("ws");
const logger_1 = require("./utils/logger");
const terminalServer_1 = require("./websocket/terminalServer");
const clients = new Map();
function setupWebSocket(wss) {
    wss.on('connection', (ws, req) => {
        if (req.url === '/terminal') {
            (0, terminalServer_1.setupTerminalSession)(ws);
            return;
        }
        const clientId = generateClientId();
        clients.set(clientId, { ws });
        logger_1.logger.info(`WebSocket client connected: ${clientId}`);
        ws.on('message', (message) => {
            try {
                const data = JSON.parse(message.toString());
                handleMessage(clientId, data);
            }
            catch (error) {
                logger_1.logger.error('WebSocket message error:', error);
            }
        });
        ws.on('close', () => {
            clients.delete(clientId);
            logger_1.logger.info(`WebSocket client disconnected: ${clientId}`);
        });
        ws.on('error', (error) => {
            logger_1.logger.error('WebSocket error:', error);
        });
    });
}
function handleMessage(clientId, data) {
    const client = clients.get(clientId);
    if (!client)
        return;
    switch (data.type) {
        case 'auth':
            // Authenticate WebSocket connection
            client.userId = data.userId;
            client.organizationId = data.organizationId;
            break;
        case 'subscribe':
            // Subscribe to scan updates
            break;
        default:
            logger_1.logger.warn(`Unknown message type: ${data.type}`);
    }
}
function broadcastScanUpdate(scanId, update) {
    const message = JSON.stringify({
        type: 'scan_update',
        scanId,
        data: update
    });
    clients.forEach((client) => {
        if (client.ws.readyState === ws_1.WebSocket.OPEN) {
            client.ws.send(message);
        }
    });
}
function sendToUser(userId, message) {
    clients.forEach((client) => {
        if (client.userId === userId && client.ws.readyState === ws_1.WebSocket.OPEN) {
            client.ws.send(JSON.stringify(message));
        }
    });
}
function generateClientId() {
    return `client_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}
//# sourceMappingURL=websocket.js.map
import { WebSocketServer, WebSocket } from 'ws';
import { logger } from './utils/logger';
import { setupTerminalSession } from './websocket/terminalServer';

interface Client {
    ws: WebSocket;
    userId?: number;
    organizationId?: number;
}

const clients: Map<string, Client> = new Map();

export function setupWebSocket(wss: WebSocketServer) {
    wss.on('connection', (ws: WebSocket, req: any) => {
        if (req.url === '/terminal') {
            setupTerminalSession(ws);
            return;
        }

        const clientId = generateClientId();
        clients.set(clientId, { ws });

        logger.info(`WebSocket client connected: ${clientId}`);

        ws.on('message', (message: string) => {
            try {
                const data = JSON.parse(message.toString());
                handleMessage(clientId, data);
            } catch (error) {
                logger.error('WebSocket message error:', error);
            }
        });

        ws.on('close', () => {
            clients.delete(clientId);
            logger.info(`WebSocket client disconnected: ${clientId}`);
        });

        ws.on('error', (error) => {
            logger.error('WebSocket error:', error);
        });
    });
}

function handleMessage(clientId: string, data: any) {
    const client = clients.get(clientId);
    if (!client) return;

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
            logger.warn(`Unknown message type: ${data.type}`);
    }
}

export function broadcastScanUpdate(scanId: number, update: any) {
    const message = JSON.stringify({
        type: 'scan_update',
        scanId,
        data: update
    });

    clients.forEach((client) => {
        if (client.ws.readyState === WebSocket.OPEN) {
            client.ws.send(message);
        }
    });
}

export function sendToUser(userId: number, message: any) {
    clients.forEach((client) => {
        if (client.userId === userId && client.ws.readyState === WebSocket.OPEN) {
            client.ws.send(JSON.stringify(message));
        }
    });
}

function generateClientId(): string {
    return `client_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

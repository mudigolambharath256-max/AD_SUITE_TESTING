"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.setupTerminalSession = setupTerminalSession;
const ws_1 = require("ws");
const pty = __importStar(require("node-pty"));
const logger_1 = require("../utils/logger");
const MAX_SESSIONS = 10;
const sessions = new Map();
function setupTerminalSession(ws) {
    if (sessions.size >= MAX_SESSIONS) {
        ws.send(JSON.stringify({ type: 'error', data: 'Maximum terminal sessions reached.' }));
        ws.close();
        return;
    }
    const sessionId = `term_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    logger_1.logger.info(`Spawning PowerShell session: ${sessionId}`);
    // Try to use PowerShell Core (pwsh) which has better UTF-8 support
    // Fall back to powershell.exe if pwsh is not available
    let shell = 'powershell.exe';
    const args = ['-ExecutionPolicy', 'Bypass', '-NoProfile', '-NoLogo'];
    const ptyProcess = pty.spawn(shell, args, {
        name: 'xterm-256color',
        cols: 120,
        rows: 40,
        cwd: process.env.USERPROFILE || process.cwd(),
        env: {
            ...process.env,
            PYTHONIOENCODING: 'utf-8',
            LANG: 'en_US.UTF-8'
        }
    });
    sessions.set(sessionId, { ws, ptyProcess });
    ws.send(JSON.stringify({ type: 'ready', sessionId }));
    ptyProcess.onData((data) => {
        if (ws.readyState === ws_1.WebSocket.OPEN) {
            // Remove null bytes
            let cleanData = data.replace(/\0/g, '');
            // FOUND THE ISSUE: PowerShell sends ESC[1C (cursor forward) after prompts
            // This causes xterm.js to add extra spacing
            cleanData = cleanData.replace(/\x1b\[1C/g, '');
            ws.send(JSON.stringify({ type: 'output', data: cleanData }));
        }
    });
    ptyProcess.onExit(({ exitCode }) => {
        logger_1.logger.info(`PowerShell session closed: ${sessionId} (Exit: ${exitCode})`);
        if (ws.readyState === ws_1.WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'closed', exitCode }));
            ws.close();
        }
        sessions.delete(sessionId);
    });
    ws.on('message', (message) => {
        try {
            const msg = JSON.parse(message.toString());
            if (msg.type === 'input') {
                ptyProcess.write(msg.data);
            }
            else if (msg.type === 'resize') {
                ptyProcess.resize(msg.cols || 120, msg.rows || 40);
            }
            else if (msg.type === 'inject-context') {
                const { domain, domainDN, targetServer } = msg;
                // Write each command on a separate line for cleaner output
                if (domain)
                    ptyProcess.write(`$global:domain="${domain}"\r`);
                if (domainDN)
                    ptyProcess.write(`$global:domainDN="${domainDN}"\r`);
                if (targetServer)
                    ptyProcess.write(`$global:targetServer="${targetServer}"\r`);
                ptyProcess.write(`Write-Host "Active Directory Context Injected." -ForegroundColor Green\r`);
            }
        }
        catch (error) {
            logger_1.logger.error('Terminal WebSocket message error:', error);
        }
    });
    ws.on('close', () => {
        try {
            ptyProcess.kill();
        }
        catch (e) { }
        sessions.delete(sessionId);
        logger_1.logger.info(`Terminal WebSocket disconnected: ${sessionId}`);
    });
}
//# sourceMappingURL=terminalServer.js.map
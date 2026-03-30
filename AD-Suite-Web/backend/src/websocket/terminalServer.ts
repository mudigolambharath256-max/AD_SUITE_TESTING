import { WebSocket } from 'ws';
import * as pty from 'node-pty';
import { logger } from '../utils/logger';

const MAX_SESSIONS = 10;
const sessions = new Map<string, any>();

export function setupTerminalSession(ws: WebSocket) {
    if (sessions.size >= MAX_SESSIONS) {
        ws.send(JSON.stringify({ type: 'error', data: 'Maximum terminal sessions reached.' }));
        ws.close();
        return;
    }

    const sessionId = `term_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

    logger.info(`Spawning PowerShell session: ${sessionId}`);

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
            ...process.env as Record<string, string>,
            PYTHONIOENCODING: 'utf-8',
            LANG: 'en_US.UTF-8'
        }
    });

    sessions.set(sessionId, { ws, ptyProcess });

    ws.send(JSON.stringify({ type: 'ready', sessionId }));

    ptyProcess.onData((data) => {
        if (ws.readyState === WebSocket.OPEN) {
            // Remove null bytes
            let cleanData = data.replace(/\0/g, '');

            // FOUND THE ISSUE: PowerShell sends ESC[1C (cursor forward) after prompts
            // This causes xterm.js to add extra spacing
            cleanData = cleanData.replace(/\x1b\[1C/g, '');

            ws.send(JSON.stringify({ type: 'output', data: cleanData }));
        }
    });

    ptyProcess.onExit(({ exitCode }) => {
        logger.info(`PowerShell session closed: ${sessionId} (Exit: ${exitCode})`);
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'closed', exitCode }));
            ws.close();
        }
        sessions.delete(sessionId);
    });

    ws.on('message', (message: string) => {
        try {
            const msg = JSON.parse(message.toString());

            if (msg.type === 'input') {
                ptyProcess.write(msg.data);
            } else if (msg.type === 'resize') {
                ptyProcess.resize(msg.cols || 120, msg.rows || 40);
            } else if (msg.type === 'inject-context') {
                const { domain, domainDN, targetServer } = msg;
                // Write each command on a separate line for cleaner output
                if (domain) ptyProcess.write(`$global:domain="${domain}"\r`);
                if (domainDN) ptyProcess.write(`$global:domainDN="${domainDN}"\r`);
                if (targetServer) ptyProcess.write(`$global:targetServer="${targetServer}"\r`);
                ptyProcess.write(`Write-Host "Active Directory Context Injected." -ForegroundColor Green\r`);
            }
        } catch (error) {
            logger.error('Terminal WebSocket message error:', error);
        }
    });

    ws.on('close', () => {
        try {
            ptyProcess.kill();
        } catch (e) { }
        sessions.delete(sessionId);
        logger.info(`Terminal WebSocket disconnected: ${sessionId}`);
    });
}

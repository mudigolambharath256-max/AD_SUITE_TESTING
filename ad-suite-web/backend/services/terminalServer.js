'use strict';

const WebSocket = require('ws');
const pty = require('@lydell/node-pty');
const os = require('os');

// ── Configuration ────────────────────────────────────────────────────────
const MAX_SESSIONS = 10;                  // Maximum concurrent terminal sessions
const IDLE_TIMEOUT_MS = 4 * 60 * 60 * 1000;   // 4 hours idle timeout
const DEFAULT_COLS = 220;
const DEFAULT_ROWS = 50;

// ── Session registry ─────────────────────────────────────────────────────
// sessionId → { ptyProcess, ws, timer, cols, rows }
const sessions = new Map();

// ── Attach WebSocket server to the existing HTTP server ──────────────────
function attachTerminalServer(httpServer) {
    const wss = new WebSocket.Server({
        server: httpServer,
        path: '/terminal',
    });

    wss.on('connection', (ws, req) => {
        // ── Reject if at session limit ──────────────────────────────────────
        if (sessions.size >= MAX_SESSIONS) {
            ws.send(JSON.stringify({ type: 'error', message: `Maximum ${MAX_SESSIONS} terminal sessions reached.` }));
            ws.close();
            return;
        }

        // ── Generate session ID ─────────────────────────────────────────────
        const sessionId = `term_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

        // ── Spawn PowerShell via node-pty (real ConPTY) ─────────────────────
        let ptyProcess;
        try {
            ptyProcess = pty.spawn('powershell.exe', [
                '-ExecutionPolicy', 'Bypass',
                '-NoProfile',
                '-NoLogo',
                // DO NOT add -NonInteractive — that disables PSReadLine
                // DO NOT add -Command — that disables the interactive prompt
            ], {
                name: 'xterm-256color',    // tells PSReadLine full colour + features are available
                cols: DEFAULT_COLS,
                rows: DEFAULT_ROWS,
                cwd: process.env.USERPROFILE || os.homedir(),
                env: {
                    ...process.env,
                    TERM: 'xterm-256color',
                    // Force PSReadLine into emacs mode (most compatible for web terminals)
                    TERM_PROGRAM: 'xterm',
                },
            });
        } catch (err) {
            ws.send(JSON.stringify({ type: 'error', message: `Failed to spawn PowerShell: ${err.message}` }));
            ws.close();
            return;
        }

        // ── Store session ───────────────────────────────────────────────────
        const session = { ptyProcess, ws, cols: DEFAULT_COLS, rows: DEFAULT_ROWS, timer: null };
        sessions.set(sessionId, session);

        // ── Send ready signal with sessionId ────────────────────────────────
        ws.send(JSON.stringify({ type: 'ready', sessionId }));

        // ── PTY output → WebSocket ───────────────────────────────────────────
        // node-pty emits raw terminal escape sequences (ANSI codes).
        // xterm.js knows how to render them — just forward as-is.
        ptyProcess.onData((data) => {
            resetIdleTimer(sessionId);
            if (ws.readyState === WebSocket.OPEN) {
                // Send raw data as text — xterm.js handles ANSI escape codes natively
                ws.send(JSON.stringify({ type: 'output', data }));
            }
        });

        // ── PTY exit ─────────────────────────────────────────────────────────
        ptyProcess.onExit(({ exitCode }) => {
            if (ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'closed', exitCode }));
                ws.close();
            }
            cleanupSession(sessionId);
        });

        // ── WebSocket → PTY ──────────────────────────────────────────────────
        ws.on('message', (raw) => {
            resetIdleTimer(sessionId);
            let msg;
            try {
                msg = JSON.parse(raw);
            } catch {
                // If the message is not JSON, treat it as raw PTY input directly
                // (fallback for older client code)
                if (sessions.has(sessionId)) {
                    sessions.get(sessionId).ptyProcess.write(raw.toString());
                }
                return;
            }

            switch (msg.type) {

                // Keyboard input: any character the user types in xterm.js
                // xterm.js sends EVERY keystroke as its terminal sequence, including:
                //   - Regular characters: 'a', 'b', etc.
                //   - Backspace:  '\x7F' or '\b'
                //   - Arrow keys: '\x1b[A' (up), '\x1b[B' (down), '\x1b[C' (right), '\x1b[D' (left)
                //   - Home:       '\x1b[H'
                //   - End:        '\x1b[F'
                //   - Delete:     '\x1b[3~'
                //   - Ctrl+C:     '\x03'
                //   - Ctrl+D:     '\x04'
                //   - Ctrl+L:     '\x0c'
                //   - Ctrl+R:     '\x12'
                //   - Tab:        '\t'
                //   - Enter:      '\r'
                // Forward ALL of them directly to the PTY — no filtering, no translation.
                case 'input':
                    if (sessions.has(sessionId)) {
                        sessions.get(sessionId).ptyProcess.write(msg.data);
                    }
                    break;

                // Terminal resize: fired when the xterm.js container resizes
                case 'resize':
                    if (sessions.has(sessionId)) {
                        const s = sessions.get(sessionId);
                        const cols = Math.max(1, Math.floor(msg.cols));
                        const rows = Math.max(1, Math.floor(msg.rows));
                        s.cols = cols;
                        s.rows = rows;
                        s.ptyProcess.resize(cols, rows);
                    }
                    break;

                case 'ping':
                    if (ws.readyState === WebSocket.OPEN) {
                        ws.send(JSON.stringify({ type: 'pong' }));
                    }
                    break;

                // Context injection request: inject AD variables into the session
                case 'inject-context': {
                    const { domain, domainDN, targetServer } = msg;
                    const commands = [];
                    if (domain) commands.push(`$global:domain       = '${domain.replace(/'/g, "''")}'`);
                    if (domainDN) commands.push(`$global:domainDN     = '${domainDN.replace(/'/g, "''")}'`);
                    if (targetServer) commands.push(`$global:targetServer = '${targetServer.replace(/'/g, "''")}'`);
                    if (commands.length > 0) {
                        // Write as a single joined command followed by Enter
                        const injection = commands.join('; ') + '\r';
                        if (sessions.has(sessionId)) {
                            sessions.get(sessionId).ptyProcess.write(injection);
                        }
                    }
                    break;
                }

                default:
                    break;
            }
        });

        // ── WebSocket close ──────────────────────────────────────────────────
        ws.on('close', () => {
            cleanupSession(sessionId);
        });

        ws.on('error', (err) => {
            console.error(`[Terminal] WebSocket error on session ${sessionId}:`, err.message);
            cleanupSession(sessionId);
        });

        // ── Start idle timer ─────────────────────────────────────────────────
        resetIdleTimer(sessionId);
    });

    console.log('[Terminal] PTY terminal server attached at /terminal');
}

// ── Helpers ───────────────────────────────────────────────────────────────

function resetIdleTimer(sessionId) {
    const session = sessions.get(sessionId);
    if (!session) return;
    clearTimeout(session.timer);
    session.timer = setTimeout(() => {
        const s = sessions.get(sessionId);
        if (!s) return;
        if (s.ws.readyState === WebSocket.OPEN) {
            s.ws.send(JSON.stringify({ type: 'closed', exitCode: -1, reason: 'idle timeout' }));
            s.ws.close();
        }
        cleanupSession(sessionId);
    }, IDLE_TIMEOUT_MS);
}

function cleanupSession(sessionId) {
    const session = sessions.get(sessionId);
    if (!session) return;
    clearTimeout(session.timer);
    try {
        session.ptyProcess.kill();
    } catch (_) { }
    sessions.delete(sessionId);
    console.log(`[Terminal] Session ${sessionId} cleaned up. Active: ${sessions.size}`);
}

module.exports = { attachTerminalServer };

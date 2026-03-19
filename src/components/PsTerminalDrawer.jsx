import { useEffect, useRef, useState } from 'react';
import { Terminal } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import { ClipboardAddon } from '@xterm/addon-clipboard';
import { WebLinksAddon } from '@xterm/addon-web-links';
import '@xterm/xterm/css/xterm.css';

// ── Drawer height states ─────────────────────────────────────────────────
const HEIGHTS = { closed: 0, minimized: 44, normal: 380, expanded: 620 };

// ── Quick commands ────────────────────────────────────────────────────────
const QUICK_CMDS = [
    { label: 'Ping DC', cmd: 'Test-Connection $global:targetServer -Count 2' },
    { label: 'LDAP 389', cmd: 'Test-NetConnection $global:targetServer -Port 389' },
    { label: 'LDAPS 636', cmd: 'Test-NetConnection $global:targetServer -Port 636' },
    { label: 'GC 3268', cmd: 'Test-NetConnection $global:targetServer -Port 3268' },
    { label: 'Kerberos 88', cmd: 'Test-NetConnection $global:targetServer -Port 88' },
    { label: 'RootDSE', cmd: '([ADSI]"LDAP://RootDSE").defaultNamingContext' },
    { label: 'DNS Lookup', cmd: 'Resolve-DnsName $global:domain' },
    { label: 'Find DC', cmd: 'nltest /dsgetdc:$global:domain' },
    { label: 'AD Full Test', cmd: '$d = $global:domain; Test-Connection $global:targetServer -Count 1; Test-NetConnection $global:targetServer -Port 389; ([ADSI]"LDAP://RootDSE").defaultNamingContext; Write-Host "Test complete" -ForegroundColor Green' },
];

export function PsTerminalDrawer({ domain, domainDN, serverIp }) {
    // Map serverIp to targetServer for backward compatibility
    const targetServer = serverIp;

    // Derive domainDN from domain if not provided
    const derivedDomainDN = domainDN || (domain ? domain.split('.').map(p => `DC=${p}`).join(',') : '');

    const containerRef = useRef(null);
    const termRef = useRef(null);
    const fitAddonRef = useRef(null);
    const wsRef = useRef(null);
    const resizeObserver = useRef(null);

    const [drawerState, setDrawerState] = useState('closed');
    const [connected, setConnected] = useState(false);
    const [sessionId, setSessionId] = useState(null);
    const [statusText, setStatusText] = useState('');

    const height = HEIGHTS[drawerState];

    // ── Initialise xterm.js ───────────────────────────────────────────────
    useEffect(() => {
        const term = new Terminal({
            fontFamily: "'Cascadia Code', 'JetBrains Mono', 'Consolas', monospace",
            fontSize: 13,
            lineHeight: 1.2,
            letterSpacing: 0,
            cursorBlink: true,
            cursorStyle: 'block',
            cursorWidth: 1,
            scrollback: 10000,
            convertEol: true,
            disableStdin: false,
            allowProposedApi: true,
            theme: {
                background: '#12100e',
                foreground: '#ede9e0',
                cursor: '#d4a96a',
                cursorAccent: '#12100e',
                selectionBackground: '#d4a96a44',
                selectionForeground: '#ede9e0',
                black: '#1a1612',
                red: '#c0392b',
                green: '#4e8c5f',
                yellow: '#d4a96a',
                blue: '#5b7fa6',
                magenta: '#8b6db5',
                cyan: '#4b8fa3',
                white: '#ede9e0',
                brightBlack: '#4a403a',
                brightRed: '#d45a47',
                brightGreen: '#6aab7e',
                brightYellow: '#e0b87a',
                brightBlue: '#7a9fc0',
                brightMagenta: '#a68bc7',
                brightCyan: '#5baabb',
                brightWhite: '#f5f2eb',
            },
        });

        const fitAddon = new FitAddon();
        const clipboardAddon = new ClipboardAddon();
        const webLinksAddon = new WebLinksAddon();

        term.loadAddon(fitAddon);
        term.loadAddon(clipboardAddon);
        term.loadAddon(webLinksAddon);

        fitAddonRef.current = fitAddon;
        termRef.current = term;

        if (containerRef.current) {
            term.open(containerRef.current);
            requestAnimationFrame(() => {
                try { fitAddon.fit(); } catch (_) { }
            });
        }

        term.onData((data) => {
            if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
                wsRef.current.send(JSON.stringify({ type: 'input', data }));
            }
        });

        const handlePaste = (e) => {
            e.preventDefault();
            const text = e.clipboardData?.getData('text');
            if (text && wsRef.current?.readyState === WebSocket.OPEN) {
                wsRef.current.send(JSON.stringify({ type: 'input', data: text }));
            }
        };

        const xtermViewport = containerRef.current?.querySelector('.xterm-helper-textarea');
        xtermViewport?.addEventListener('paste', handlePaste);

        return () => {
            xtermViewport?.removeEventListener('paste', handlePaste);
            term.dispose();
        };
    }, []);

    // ── ResizeObserver ─────────────────────────────────────────────────────
    useEffect(() => {
        if (!containerRef.current) return;

        resizeObserver.current = new ResizeObserver(() => {
            if (!fitAddonRef.current || !termRef.current) return;
            try {
                fitAddonRef.current.fit();
                const { cols, rows } = termRef.current;
                if (wsRef.current?.readyState === WebSocket.OPEN) {
                    wsRef.current.send(JSON.stringify({ type: 'resize', cols, rows }));
                }
            } catch (_) { }
        });

        resizeObserver.current.observe(containerRef.current);
        return () => resizeObserver.current?.disconnect();
    }, []);

    // ── Connect WebSocket ──────────────────────────────────────────────────
    useEffect(() => {
        if (drawerState === 'closed') return;

        if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
            focusTerminal();
            return;
        }

        connectWebSocket();
    }, [drawerState]);

    // ── Re-fit when drawer height changes ──────────────────────────────────
    useEffect(() => {
        if (drawerState === 'minimized' || drawerState === 'closed') return;
        requestAnimationFrame(() => {
            try {
                fitAddonRef.current?.fit();
                const { cols, rows } = termRef.current || {};
                if (cols && rows && wsRef.current?.readyState === WebSocket.OPEN) {
                    wsRef.current.send(JSON.stringify({ type: 'resize', cols, rows }));
                }
            } catch (_) { }
        });
    }, [drawerState]);

    // ── WebSocket connection ───────────────────────────────────────────────
    function connectWebSocket() {
        setStatusText('Connecting…');

        const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
        const ws = new WebSocket(`${protocol}://${window.location.host}/terminal`);

        ws.onopen = () => {
            setStatusText('Connected — waiting for shell…');
        };

        ws.onmessage = (event) => {
            let msg;
            try {
                msg = JSON.parse(event.data);
            } catch {
                termRef.current?.write(event.data);
                return;
            }

            switch (msg.type) {
                case 'ready':
                    setSessionId(msg.sessionId);
                    setConnected(true);
                    setStatusText('PowerShell ready');

                    requestAnimationFrame(() => {
                        try { fitAddonRef.current?.fit(); } catch (_) { }
                        const { cols, rows } = termRef.current || {};
                        if (cols && rows) {
                            ws.send(JSON.stringify({ type: 'resize', cols, rows }));
                        }
                    });

                    setTimeout(() => {
                        if (domain || derivedDomainDN || targetServer) {
                            ws.send(JSON.stringify({
                                type: 'inject-context',
                                domain,
                                domainDN: derivedDomainDN,
                                targetServer,
                            }));
                        }
                    }, 800);

                    focusTerminal();
                    break;

                case 'output':
                    termRef.current?.write(msg.data);
                    break;

                case 'closed':
                    termRef.current?.write('\r\n\x1b[33m[Session ended]\x1b[0m\r\n');
                    setConnected(false);
                    setStatusText('Session ended');
                    setSessionId(null);
                    break;

                case 'error':
                    termRef.current?.write(`\r\n\x1b[31m[Error] ${msg.message}\x1b[0m\r\n`);
                    setStatusText(`Error: ${msg.message}`);
                    break;

                case 'pong':
                    break;

                default:
                    break;
            }
        };

        ws.onclose = () => {
            setConnected(false);
            setStatusText('Disconnected');
            wsRef.current = null;
        };

        ws.onerror = (err) => {
            setStatusText('Connection error');
            termRef.current?.write('\r\n\x1b[31m[WebSocket error — check backend]\x1b[0m\r\n');
        };

        wsRef.current = ws;
    }

    // ── Helpers ────────────────────────────────────────────────────────────
    function focusTerminal() {
        requestAnimationFrame(() => termRef.current?.focus());
    }

    function sendCommand(cmd) {
        if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) return;
        wsRef.current.send(JSON.stringify({ type: 'input', data: cmd + '\r' }));
        focusTerminal();
    }

    function clearTerminal() {
        if (wsRef.current?.readyState === WebSocket.OPEN) {
            wsRef.current.send(JSON.stringify({ type: 'input', data: '\x0c' }));
        }
    }

    function reconnect() {
        if (wsRef.current) {
            try { wsRef.current.close(); } catch (_) { }
            wsRef.current = null;
        }
        setConnected(false);
        setSessionId(null);
        termRef.current?.clear();
        connectWebSocket();
    }

    function cycleHeight() {
        setDrawerState(s => {
            if (s === 'closed') return 'normal';
            if (s === 'normal') return 'expanded';
            if (s === 'expanded') return 'minimized';
            return 'normal';
        });
    }

    // ── Render ─────────────────────────────────────────────────────────────
    return (
        <>
            {/* Floating open button when closed */}
            {drawerState === 'closed' && (
                <div style={{
                    position: 'fixed',
                    bottom: 20,
                    right: 20,
                    zIndex: 1000,
                }}>
                    <button
                        onClick={() => setDrawerState('normal')}
                        title="Open PowerShell terminal"
                        style={{
                            ...btnStyle('#d4a96a', '#2e2318'),
                            padding: '8px 16px',
                            fontSize: 14,
                            boxShadow: '0 4px 12px rgba(0,0,0,0.3)',
                            borderRadius: '6px',
                        }}
                    >
                        ⚡ PowerShell Terminal
                    </button>
                </div>
            )}

            {/* Terminal Drawer - always in DOM but visibility controlled */}
            <div
                style={{
                    position: 'fixed',
                    bottom: 0,
                    left: 0,
                    right: 0,
                    zIndex: 50,
                    height: `${height}px`,
                    transition: 'height 0.2s ease',
                    overflow: 'hidden',
                    display: drawerState === 'closed' ? 'none' : 'flex',
                    flexDirection: 'column',
                    backgroundColor: '#12100e',
                    borderTop: `2px solid #3d3530`,
                }}
            >
                {/* Toolbar */}
                <div
                    style={{
                        height: 44,
                        minHeight: 44,
                        display: 'flex',
                        alignItems: 'center',
                        padding: '0 12px',
                        gap: 8,
                        backgroundColor: '#1e1b18',
                        borderBottom: drawerState !== 'minimized' ? '1px solid #3d3530' : 'none',
                        flexShrink: 0,
                    }}
                >
                    <button
                        onClick={cycleHeight}
                        title="Toggle terminal"
                        style={btnStyle('#d4a96a', '#2e2318')}
                    >
                        ⚡ PowerShell
                    </button>

                    <span style={{
                        width: 8, height: 8, borderRadius: '50%', flexShrink: 0,
                        backgroundColor: connected ? '#4e8c5f' : '#c0392b',
                    }} />
                    <span style={{ fontSize: 11, color: '#6b5f54', flexShrink: 0 }}>
                        {statusText || (connected ? 'Connected' : 'Not connected')}
                    </span>

                    {drawerState !== 'minimized' && drawerState !== 'closed' && (
                        <>
                            <div style={{ width: 1, height: 20, backgroundColor: '#3d3530', flexShrink: 0 }} />
                            <div style={{ display: 'flex', gap: 4, overflowX: 'auto', flex: 1 }}>
                                {QUICK_CMDS.map(({ label, cmd }) => (
                                    <button
                                        key={label}
                                        onClick={() => sendCommand(cmd)}
                                        disabled={!connected}
                                        title={cmd}
                                        style={btnStyle('#9b8e7e', '#2d2926', true)}
                                    >
                                        {label}
                                    </button>
                                ))}
                            </div>

                            <button onClick={clearTerminal} disabled={!connected} style={btnStyle('#6b5f54', '#1a1612', true)}>⌫ Clear</button>
                            <button onClick={reconnect} style={btnStyle('#6b5f54', '#1a1612', true)}>↺ Reconnect</button>
                            <button onClick={() => setDrawerState(s => s === 'expanded' ? 'normal' : 'expanded')}
                                style={btnStyle('#6b5f54', '#1a1612', true)}>
                                {drawerState === 'expanded' ? '⊟ Shrink' : '⊞ Expand'}
                            </button>
                            <button onClick={() => setDrawerState('closed')} style={btnStyle('#6b5f54', '#1a1612', true)}>✕</button>
                        </>
                    )}

                    {drawerState === 'minimized' && (
                        <button onClick={() => setDrawerState('normal')} style={btnStyle('#9b8e7e', '#2d2926', true)}>
                            Open Terminal
                        </button>
                    )}
                </div>

                {/* Terminal container */}
                <div
                    ref={containerRef}
                    style={{
                        flex: 1,
                        overflow: 'hidden',
                        padding: '4px 8px',
                    }}
                    onClick={focusTerminal}
                />
            </div>
        </>
    );
}

// ── Button style helper ────────────────────────────────────────────────────
function btnStyle(color, bg, small = false) {
    return {
        color,
        backgroundColor: bg,
        border: `1px solid ${color}33`,
        padding: small ? '2px 8px' : '4px 12px',
        fontSize: small ? 11 : 12,
        fontFamily: "'JetBrains Mono', monospace",
        cursor: 'pointer',
        whiteSpace: 'nowrap',
        flexShrink: 0,
        transition: 'opacity 0.15s',
        opacity: 1,
    };
}

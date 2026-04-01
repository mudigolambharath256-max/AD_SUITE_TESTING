import { useEffect, useRef, useState } from 'react';
import { Terminal as XTerm } from 'xterm';
import { FitAddon } from '@xterm/addon-fit';
import { WebLinksAddon } from '@xterm/addon-web-links';
import { ClipboardAddon } from '@xterm/addon-clipboard';
import 'xterm/css/xterm.css';
import { Play, TerminalSquare, AlertCircle, RefreshCw } from 'lucide-react';
import { useAppStore } from '../store/useAppStore';

// Add custom CSS for terminal spacing
const terminalStyles = `
.xterm {
    padding: 8px !important;
}
.xterm-viewport {
    overflow-y: auto !important;
}
.xterm-screen {
    padding: 0 !important;
}
`;

const QUICK_CMDS = [
    { label: 'Ping Server', cmd: 'Test-Connection $global:targetServer -Count 2' },
    { label: 'LDAP Ping', cmd: 'Test-NetConnection $global:targetServer -Port 389' },
    { label: 'Kerberos Ping', cmd: 'Test-NetConnection $global:targetServer -Port 88' },
    { label: 'DNS Resolve', cmd: 'Resolve-DnsName $global:domain' },
    { label: 'Get RootDSE', cmd: '([ADSI]"LDAP://RootDSE").defaultNamingContext' }
];

export default function TerminalPage() {
    const terminalRef = useRef<HTMLDivElement>(null);
    const wsRef = useRef<WebSocket | null>(null);
    const xtermRef = useRef<XTerm | null>(null);
    const fitAddonRef = useRef<FitAddon | null>(null);

    const [connected, setConnected] = useState(false);
    const [statusText, setStatusText] = useState('Connecting...');

    // Manual Overrides
    const [manualDomain, setManualDomain] = useState('');
    const [manualServerIp, setManualServerIp] = useState('');

    // Grab context from Zustand AppStore
    const { domain, serverIp } = useAppStore();

    // Effective context values
    const effectiveDomain = manualDomain || domain || 'technieum.com';
    const effectiveServerIp = manualServerIp || serverIp || '192.168.1.100';
    const effectiveDomainDN = effectiveDomain.split('.').map(p => `DC=${p}`).join(',');

    useEffect(() => {
        // Inject custom terminal styles
        const styleElement = document.createElement('style');
        styleElement.textContent = terminalStyles;
        document.head.appendChild(styleElement);

        return () => {
            document.head.removeChild(styleElement);
        };
    }, []);

    useEffect(() => {
        if (!terminalRef.current) return;

        // Clear any existing terminal instance
        if (xtermRef.current) {
            xtermRef.current.dispose();
        }

        // ... (previous xterm initialization remains same)
        const term = new XTerm({
            fontFamily: "'Consolas', 'Courier New', monospace",
            fontSize: 14,
            lineHeight: 1.0,
            letterSpacing: 0,
            cursorBlink: true,
            scrollback: 10000,
            cols: 120,
            rows: 30,
            convertEol: true,
            windowsMode: true,  // Enable Windows console mode
            theme: {
                background: '#12100e',
                foreground: '#ede9e0',
                cursor: '#d4a96a',
                selectionBackground: '#d4a96a44',
                selectionForeground: '#ede9e0',
            }
        });

        const fitAddon = new FitAddon();
        term.loadAddon(fitAddon);
        term.loadAddon(new WebLinksAddon());
        term.loadAddon(new ClipboardAddon());

        term.open(terminalRef.current);
        fitAddon.fit();

        // Clear terminal on startup
        term.clear();

        // Ensure proper terminal spacing
        setTimeout(() => {
            fitAddon.fit();
        }, 100);

        xtermRef.current = term;
        fitAddonRef.current = fitAddon;

        // Connect WebSocket (always use WS port on the same host — not the Vite dev port)
        const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
        const wsPort = import.meta.env.VITE_WS_PORT || '3001';
        const host = `${window.location.hostname}:${wsPort}`;
        const ws = new WebSocket(`${protocol}://${host}/terminal`);
        wsRef.current = ws;

        ws.onopen = () => {
            setStatusText('Connection established. Waiting for prompt...');
            // Clear any stale data
            term.clear();
            term.write('\x1b[32m[Connected to PowerShell Terminal]\x1b[0m\r\n');
        };

        ws.onmessage = (event) => {
            const msg = JSON.parse(event.data);
            if (msg.type === 'ready') {
                setConnected(true);
                setStatusText('Connected to PowerShell');
                // Inject Context using effective values (manual or store)
                setTimeout(() => {
                    if (ws.readyState === WebSocket.OPEN) {
                        ws.send(JSON.stringify({
                            type: 'inject-context',
                            domain: effectiveDomain,
                            domainDN: effectiveDomainDN,
                            targetServer: effectiveServerIp
                        }));
                    }
                }, 800);
            } else if (msg.type === 'output') {
                term.write(msg.data);
            } else if (msg.type === 'closed') {
                setConnected(false);
                setStatusText(`Session closed (Exit Code: ${msg.exitCode})`);
                term.write(`\r\n\x1b[31m[Process exited with code ${msg.exitCode}]\x1b[0m\r\n`);
            } else if (msg.type === 'error') {
                setStatusText(`Error: ${msg.data}`);
                term.write(`\r\n\x1b[31m[Error: ${msg.data}]\x1b[0m\r\n`);
            }
        };

        ws.onerror = () => {
            setConnected(false);
            setStatusText('WebSocket Error');
        };

        ws.onclose = () => {
            setConnected(false);
            setStatusText('Disconnected');
        };

        term.onData((data) => {
            if (ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'input', data }));
            }
        });

        const handleResize = () => {
            fitAddon.fit();
            if (ws.readyState === WebSocket.OPEN && term.cols && term.rows) {
                ws.send(JSON.stringify({
                    type: 'resize',
                    cols: term.cols,
                    rows: term.rows
                }));
            }
        };
        window.addEventListener('resize', handleResize);
        setTimeout(handleResize, 100);

        return () => {
            window.removeEventListener('resize', handleResize);

            // Clean up WebSocket
            if (wsRef.current) {
                if (wsRef.current.readyState === WebSocket.OPEN) {
                    wsRef.current.close();
                }
                wsRef.current = null;
            }

            // Clean up terminal
            if (xtermRef.current) {
                xtermRef.current.dispose();
                xtermRef.current = null;
            }

            fitAddonRef.current = null;
        };
    }, [effectiveDomain, effectiveDomainDN, effectiveServerIp]); // eslint-disable-line react-hooks/exhaustive-deps

    const applyContext = () => {
        if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
            wsRef.current.send(JSON.stringify({
                type: 'inject-context',
                domain: effectiveDomain,
                domainDN: effectiveDomainDN,
                targetServer: effectiveServerIp
            }));
            xtermRef.current?.write(`\r\n\x1b[36m[System] Applied Context: ${effectiveDomain} (${effectiveServerIp})\x1b[0m\r\n`);
        }
    };

    const executeCommand = (cmd: string) => {
        if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
            wsRef.current.send(JSON.stringify({ type: 'input', data: `${cmd}\r` }));
        }
    };

    const reconnect = () => {
        window.location.reload();
    };

    return (
        <div className="h-full flex flex-col space-y-4 animate-in fade-in slide-in-from-bottom-4 duration-500" style={{ height: 'calc(100vh - 6rem)' }}>
            <header className="flex items-center justify-between">
                <div>
                    <h1 className="text-3xl font-bold text-text-primary flex items-center gap-3">
                        <TerminalSquare className="text-accent-orange" /> PowerShell Studio
                    </h1>
                    <p className="text-text-secondary mt-1">Direct interactive administration terminal</p>
                </div>

                <div className="flex items-center gap-3">
                    <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-surface-elevated border border-border-light text-sm">
                        <span className={`w-2.5 h-2.5 rounded-full ${connected ? 'bg-green-500 animate-pulse' : 'bg-red-500'}`} />
                        <span className="font-medium text-text-secondary">{statusText}</span>
                    </div>
                    {!connected && (
                        <button onClick={reconnect} className="p-2 bg-surface-elevated hover:bg-bg-hover text-text-secondary rounded-lg border border-border-light transition-colors" title="Reconnect">
                            <RefreshCw size={18} />
                        </button>
                    )}
                </div>
            </header>

            {/* Manual Context Overrides */}
            <div className="bg-surface-elevated border border-border-light rounded-xl p-3 flex items-center gap-6 shadow-sm">
                <div className="flex items-center gap-4 flex-1">
                    <div className="flex flex-col gap-1 flex-1">
                        <label className="text-[10px] uppercase font-bold text-text-tertiary px-1">Override Domain</label>
                        <input
                            type="text"
                            value={manualDomain}
                            onChange={(e) => setManualDomain(e.target.value)}
                            placeholder={domain || "technieum.com (default)"}
                            className="bg-bg-primary border border-border-light rounded-lg px-3 py-1.5 text-sm text-text-primary focus:border-accent-orange outline-none transition-all placeholder:text-text-tertiary/50"
                        />
                    </div>
                    <div className="flex flex-col gap-1 flex-1">
                        <label className="text-[10px] uppercase font-bold text-text-tertiary px-1">Override Server IP</label>
                        <input
                            type="text"
                            value={manualServerIp}
                            onChange={(e) => setManualServerIp(e.target.value)}
                            placeholder={serverIp || "192.168.1.100 (default)"}
                            className="bg-bg-primary border border-border-light rounded-lg px-3 py-1.5 text-sm text-text-primary focus:border-accent-orange outline-none transition-all placeholder:text-text-tertiary/50"
                        />
                    </div>
                    <button
                        onClick={applyContext}
                        disabled={!connected}
                        className="mt-5 px-4 py-1.5 bg-accent-orange text-white rounded-lg text-sm font-semibold hover:bg-accent-orange-dark disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-md shadow-accent-orange/20"
                    >
                        Apply Context
                    </button>
                </div>
                <div className="h-10 w-px bg-border-light hidden md:block" />
                <div className="hidden md:flex flex-col text-xs text-text-tertiary">
                    <span>Effective: <span className="text-text-secondary font-mono">{effectiveDomain}</span></span>
                    <span>Target: <span className="text-text-secondary font-mono">{effectiveServerIp}</span></span>
                </div>
            </div>

            <div className="flex-1 flex gap-4 min-h-0">
                {/* Terminal Window */}
                <div className="flex-1 bg-[#12100e] rounded-xl border border-border-medium overflow-hidden shadow-inner">
                    <div ref={terminalRef} className="w-full h-full" style={{ padding: '8px' }} />
                </div>

                {/* Quick Actions Panel */}
                <div className="w-72 flex flex-col gap-4">
                    <div className="bg-surface-elevated border border-border-light rounded-xl p-5 shadow-sm overflow-y-auto">
                        <h2 className="text-base font-semibold text-text-primary mb-4 flex items-center gap-2">
                            <Play size={16} className="text-accent-orange" />
                            Quick Commands
                        </h2>
                        <div className="space-y-2">
                            {QUICK_CMDS.map((cmd, idx) => (
                                <button
                                    key={idx}
                                    onClick={() => executeCommand(cmd.cmd)}
                                    disabled={!connected}
                                    className="w-full text-left px-3 py-2 text-sm bg-bg-primary hover:bg-accent-orange-light hover:text-accent-orange text-text-secondary border border-border-light hover:border-accent-orange rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed group whitespace-nowrap overflow-hidden"
                                >
                                    <span className="block font-medium">{cmd.label}</span>
                                    <span className="block text-xs text-text-tertiary truncate mt-0.5 group-hover:text-accent-orange/70">
                                        {cmd.cmd}
                                    </span>
                                </button>
                            ))}
                        </div>
                    </div>

                    <div className="bg-info/10 border border-info/20 rounded-xl p-4 flex gap-3 text-sm text-info/90">
                        <AlertCircle size={20} className="shrink-0" />
                        <p>
                            Context variables ($global:domain etc.) are updated when you hit "Apply Context" or re-connect.
                        </p>
                    </div>
                </div>
            </div>
        </div>
    );
}

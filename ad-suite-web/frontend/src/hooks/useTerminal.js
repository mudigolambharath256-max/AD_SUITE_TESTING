import { useEffect, useRef, useCallback, useState } from 'react';
import { Terminal } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import { WebLinksAddon } from '@xterm/addon-web-links';
import '@xterm/xterm/css/xterm.css';

export function useTerminal({ containerRef, isOpen, domain, serverIp }) {
    const termRef = useRef(null);
    const fitAddonRef = useRef(null);
    const wsRef = useRef(null);
    const [status, setStatus] = useState('disconnected');
    // status: 'disconnected' | 'connecting' | 'ready' | 'closed' | 'error'
    const [errorMessage, setErrorMessage] = useState('');

    // ── Build the WebSocket URL ──────────────────────────────────────────────
    function buildWsUrl() {
        const isHttps = window.location.protocol === 'https:';
        const proto = isHttps ? 'wss' : 'ws';
        // In dev (port 5173), Vite proxies /terminal to 3001
        // In prod, the server serves everything from 3001
        return `${proto}://${window.location.hostname}:${window.location.port === '5173' ? window.location.port : '3001'
            }/terminal`;
    }

    // ── Initialise xterm.js (once, when container is available) ─────────────
    useEffect(() => {
        if (!containerRef.current || termRef.current) return;

        const term = new Terminal({
            cursorBlink: true,
            cursorStyle: 'block',
            fontSize: 13,
            lineHeight: 1.4,
            letterSpacing: 0,
            fontFamily: "'JetBrains Mono', 'Cascadia Code', 'Cascadia Mono', 'Consolas', monospace",
            scrollback: 5000,
            allowProposedApi: true,
            theme: {
                background: '#12100e',
                foreground: '#ede9e0',
                cursor: '#d4a96a',
                cursorAccent: '#12100e',
                selectionBackground: '#d4a96a44',
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
        const webLinksAddon = new WebLinksAddon();
        term.loadAddon(fitAddon);
        term.loadAddon(webLinksAddon);
        term.open(containerRef.current);

        // Fit after a frame to ensure container has rendered dimensions
        requestAnimationFrame(() => fitAddon.fit());

        termRef.current = term;
        fitAddonRef.current = fitAddon;

        // Forward resize events to backend (informational only for piped PS)
        term.onResize(({ cols, rows }) => {
            if (wsRef.current?.readyState === WebSocket.OPEN) {
                wsRef.current.send(JSON.stringify({ type: 'resize', cols, rows }));
            }
        });

        // ResizeObserver — refit when container dimensions change
        const observer = new ResizeObserver(() => {
            requestAnimationFrame(() => fitAddon.fit());
        });
        observer.observe(containerRef.current);

        return () => {
            observer.disconnect();
            term.dispose();
            termRef.current = null;
            fitAddonRef.current = null;
        };
    }, [containerRef]);

    // ── Connect WebSocket (when terminal opens) ──────────────────────────────
    useEffect(() => {
        if (!isOpen || !termRef.current) return;
        if (wsRef.current?.readyState === WebSocket.OPEN) return; // already connected

        connect();

        return () => {
            // Do NOT close ws here — keep session alive when drawer is minimized
            // Only close on component unmount (see cleanup below)
        };
    }, [isOpen]);

    // ── Cleanup on unmount ───────────────────────────────────────────────────
    useEffect(() => {
        return () => {
            if (wsRef.current) {
                wsRef.current.close();
                wsRef.current = null;
            }
        };
    }, []);

    function connect() {
        if (!termRef.current) return;
        setStatus('connecting');

        const ws = new WebSocket(buildWsUrl());
        wsRef.current = ws;

        ws.onopen = () => {
            // Send context init with current domain/IP values
            ws.send(JSON.stringify({
                type: 'init',
                domain: domain || '',
                serverIp: serverIp || '',
            }));
        };

        ws.onmessage = (event) => {
            let msg;
            try { msg = JSON.parse(event.data); } catch { return; }

            if (msg.type === 'ready') {
                setStatus('ready');
                requestAnimationFrame(() => fitAddonRef.current?.fit());
            }
            else if (msg.type === 'output') {
                termRef.current?.write(msg.data);
            }
            else if (msg.type === 'closed') {
                setStatus('closed');
            }
            else if (msg.type === 'error') {
                setStatus('error');
                setErrorMessage(msg.message);
                termRef.current?.writeln('\x1b[31m' + msg.message + '\x1b[0m');
            }
        };

        ws.onerror = () => {
            setStatus('error');
            setErrorMessage('WebSocket connection failed. Is the backend server running?');
            termRef.current?.writeln('\x1b[31m[Connection error — check that the backend is running on port 3001]\x1b[0m');
        };

        ws.onclose = () => {
            if (status !== 'error') setStatus('disconnected');
        };

        // Forward xterm input to backend
        termRef.current.onData((data) => {
            if (ws.readyState === WebSocket.OPEN) {
                ws.send(JSON.stringify({ type: 'input', data }));
            }
        });
    }

    // ── Public API ───────────────────────────────────────────────────────────

    const sendCommand = useCallback((command) => {
        if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) return;
        // Commands from quick-buttons are sent as full lines
        wsRef.current.send(JSON.stringify({ type: 'input', data: command + '\r' }));
        termRef.current?.focus();
    }, []);

    const clearTerminal = useCallback(() => {
        termRef.current?.clear();
    }, []);

    const reconnect = useCallback(() => {
        if (wsRef.current) {
            wsRef.current.close();
            wsRef.current = null;
        }
        setStatus('disconnected');
        setErrorMessage('');
        setTimeout(connect, 200);
    }, [domain, serverIp]);

    const injectContext = useCallback(() => {
        if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) return;
        wsRef.current.send(JSON.stringify({
            type: 'init',
            domain: domain || '',
            serverIp: serverIp || '',
        }));
    }, [domain, serverIp]);

    const focus = useCallback(() => {
        termRef.current?.focus();
    }, []);

    return { status, errorMessage, sendCommand, clearTerminal, reconnect, injectContext, focus };
}

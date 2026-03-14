import { useState, useRef, useEffect } from 'react';

export function AdExplorerSection({ onOpenInGraph }) {
    const fileInputRef = useRef(null);
    const [snapshotPath, setSnapshotPath] = useState('');
    const [convertExePath, setConvertExePath] = useState('');
    const [sessionId, setSessionId] = useState(null);
    const [status, setStatus] = useState('idle'); // idle | running | complete | error
    const [logLines, setLogLines] = useState([]);
    const [outputFiles, setOutputFiles] = useState([]);
    const [graphAvailable, setGraphAvailable] = useState(false);
    const [summaryText, setSummaryText] = useState('');
    const logBoxRef = useRef(null);

    // Auto-scroll log box to bottom
    useEffect(() => {
        if (logBoxRef.current) {
            logBoxRef.current.scrollTop = logBoxRef.current.scrollHeight;
        }
    }, [logLines.length]);

    function handleBrowse(setter, accept = '.dat,.exe') {
        if (!fileInputRef.current) return;

        fileInputRef.current.accept = accept;
        fileInputRef.current.onchange = (e) => {
            const f = e.target.files[0];
            if (f) setter(f.path || f.name);  // Electron gives .path, browser gives .name
            fileInputRef.current.value = '';  // reset so same file can be re-selected
        };
        fileInputRef.current.click();
    }

    async function handleConvert() {
        if (!snapshotPath.trim()) {
            setStatus('error');
            setLogLines([{ type: 'err', text: 'Please provide a snapshot file path' }]);
            return;
        }

        setStatus('running');
        setLogLines([]);
        setOutputFiles([]);
        setGraphAvailable(false);
        setSummaryText('');

        try {
            const res = await fetch('/api/integrations/adexplorer/convert', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    snapshotPath,
                    convertExePath: convertExePath.trim() || undefined
                }),
            });

            if (!res.ok) {
                const err = await res.json();
                setStatus('error');
                setLogLines([{ type: 'err', text: err.error }]);
                return;
            }

            const { sessionId: sid } = await res.json();
            setSessionId(sid);

            // Open SSE stream for live progress
            const sse = new EventSource(`/api/integrations/adexplorer/stream/${sid}`);

            sse.onmessage = (e) => {
                const msg = JSON.parse(e.data);

                if (msg.type === 'log') {
                    setLogLines(prev => [...prev.slice(-499), msg]);  // ring buffer 500 lines
                }

                if (msg.type === 'complete') {
                    setStatus(msg.code === 0 ? 'complete' : 'error');
                    setOutputFiles(msg.outputFiles || []);
                    setGraphAvailable(msg.graphAvailable || false);
                    setSummaryText(msg.summary || '');
                    sse.close();
                }

                if (msg.type === 'error') {
                    setStatus('error');
                    setLogLines(prev => [...prev, { type: 'err', text: msg.message }]);
                    sse.close();
                }
            };

            sse.onerror = () => {
                setStatus('error');
                setLogLines(prev => [...prev, { type: 'err', text: 'Connection to server lost' }]);
                sse.close();
            };
        } catch (error) {
            setStatus('error');
            setLogLines([{ type: 'err', text: error.message }]);
        }
    }

    async function handleDownload(filename) {
        try {
            const res = await fetch(`/api/integrations/adexplorer/download/${sessionId}/${filename}`);
            if (!res.ok) throw new Error('Download failed');

            const blob = await res.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = filename;
            a.click();
            window.URL.revokeObjectURL(url);
        } catch (error) {
            console.error('Download error:', error);
        }
    }

    async function handlePushToBloodHound(filename) {
        try {
            // Download the file content
            const res = await fetch(`/api/integrations/adexplorer/download/${sessionId}/${filename}`);
            if (!res.ok) throw new Error('Failed to fetch file');

            const data = await res.json();

            // Push to BloodHound using existing integration endpoint
            const pushRes = await fetch('/api/integrations/bloodhound/push', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ data }),
            });

            if (!pushRes.ok) throw new Error('Failed to push to BloodHound');

            alert(`Successfully pushed ${filename} to BloodHound`);
        } catch (error) {
            alert(`Error pushing to BloodHound: ${error.message}`);
        }
    }

    function getStatusBadge() {
        switch (status) {
            case 'running':
                return (
                    <span className="inline-flex items-center gap-1.5 px-2 py-1 rounded text-xs bg-blue-500/20 text-blue-400 border border-blue-500/30">
                        <span className="w-2 h-2 rounded-full bg-blue-400 animate-pulse" />
                        Converting...
                    </span>
                );
            case 'complete':
                return (
                    <span className="inline-flex items-center gap-1.5 px-2 py-1 rounded text-xs bg-green-500/20 text-green-400 border border-green-500/30">
                        ✓ Complete
                    </span>
                );
            case 'error':
                return (
                    <span className="inline-flex items-center gap-1.5 px-2 py-1 rounded text-xs bg-red-500/20 text-red-400 border border-red-500/30">
                        ✕ Error
                    </span>
                );
            default:
                return null;
        }
    }

    return (
        <div className="rounded-xl border border-border bg-bg-secondary overflow-hidden">
            <input type="file" ref={fileInputRef} style={{ display: 'none' }} />

            {/* Header */}
            <div className="p-4 border-b border-border">
                <h3 className="text-text-primary font-semibold">ADExplorer Snapshot Converter</h3>
                <p className="text-text-secondary text-sm mt-1">
                    Upload a Sysinternals ADExplorer .dat snapshot file and convert it to BloodHound-compatible JSON format.
                    The converter can use either a pure PowerShell parser or the optional convertsnapshot.exe tool for best results.
                </p>
            </div>

            {/* Configuration */}
            <div className="p-4 space-y-3">
                {/* Snapshot file path */}
                <div>
                    <label className="block text-text-secondary text-sm mb-1.5">
                        Snapshot file (.dat):
                    </label>
                    <div className="flex gap-2">
                        <input
                            type="text"
                            value={snapshotPath}
                            onChange={e => setSnapshotPath(e.target.value)}
                            placeholder="C:\path\to\snapshot.dat"
                            className="flex-1 bg-bg-primary border border-border rounded-lg px-3 py-2
                         text-text-primary text-sm font-mono placeholder:text-text-muted
                         focus:outline-none focus:border-accent-primary"
                        />
                        <button
                            onClick={() => handleBrowse(setSnapshotPath, '.dat')}
                            className="px-4 py-2 bg-bg-tertiary border border-border rounded-lg
                         text-text-secondary text-sm hover:bg-bg-primary transition-colors"
                        >
                            Browse
                        </button>
                    </div>
                </div>

                {/* Optional convertsnapshot.exe path */}
                <div>
                    <label className="block text-text-secondary text-sm mb-1.5">
                        convertsnapshot.exe path (optional — for best results):
                    </label>
                    <div className="flex gap-2">
                        <input
                            type="text"
                            value={convertExePath}
                            onChange={e => setConvertExePath(e.target.value)}
                            placeholder="C:\tools\convertsnapshot.exe (optional)"
                            className="flex-1 bg-bg-primary border border-border rounded-lg px-3 py-2
                         text-text-primary text-sm font-mono placeholder:text-text-muted
                         focus:outline-none focus:border-accent-primary"
                        />
                        <button
                            onClick={() => handleBrowse(setConvertExePath, '.exe')}
                            className="px-4 py-2 bg-bg-tertiary border border-border rounded-lg
                         text-text-secondary text-sm hover:bg-bg-primary transition-colors"
                        >
                            Browse
                        </button>
                    </div>
                    <p className="text-text-muted text-xs mt-1.5 flex items-center gap-1">
                        ℹ️ Download from:
                        <a
                            href="https://github.com/t94j0/adexplorersnapshot-rs"
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-accent-primary hover:underline"
                        >
                            github.com/t94j0/adexplorersnapshot-rs
                        </a>
                    </p>
                </div>

                {/* Convert button */}
                <div className="flex items-center gap-3 pt-2">
                    <button
                        onClick={handleConvert}
                        disabled={status === 'running'}
                        className="bg-accent-primary hover:bg-accent-hover text-bg-primary font-medium
                       px-6 py-2 rounded-lg transition-all active:scale-95
                       disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        {status === 'running' ? 'Converting...' : 'Convert Snapshot'}
                    </button>
                    {getStatusBadge()}
                </div>
            </div>

            {/* Progress log */}
            {logLines.length > 0 && (
                <div className="px-4 pb-4">
                    <div className="border-t border-border pt-3">
                        <h4 className="text-text-secondary text-sm mb-2">Progress:</h4>
                        <div
                            ref={logBoxRef}
                            className="bg-[#12100e] rounded-lg p-3 font-mono text-xs overflow-y-auto"
                            style={{ maxHeight: '200px' }}
                        >
                            {logLines.map((line, i) => (
                                <div
                                    key={i}
                                    className={line.type === 'err' ? 'text-red-400' : 'text-gray-400'}
                                >
                                    {line.line || line.text}
                                </div>
                            ))}
                        </div>
                    </div>
                </div>
            )}

            {/* Output files */}
            {status === 'complete' && outputFiles.length > 0 && (
                <div className="px-4 pb-4">
                    <div className="border-t border-border pt-3">
                        <h4 className="text-text-secondary text-sm mb-2">Output Files:</h4>
                        {summaryText && (
                            <p className="text-text-muted text-xs mb-3 font-mono">{summaryText}</p>
                        )}
                        <div className="space-y-2">
                            {outputFiles.map(file => (
                                <div
                                    key={file}
                                    className="flex items-center justify-between bg-bg-primary border border-border
                             rounded-lg px-3 py-2"
                                >
                                    <span className="text-text-primary text-sm font-mono flex items-center gap-2">
                                        📄 {file}
                                    </span>
                                    <div className="flex gap-2">
                                        <button
                                            onClick={() => handleDownload(file)}
                                            className="text-xs px-3 py-1 bg-bg-tertiary border border-border rounded
                                 text-text-secondary hover:text-accent-primary transition-colors"
                                        >
                                            ↓ Download
                                        </button>
                                        {(file.includes('users') || file.includes('groups') || file.includes('computers')) && (
                                            <button
                                                onClick={() => handlePushToBloodHound(file)}
                                                className="text-xs px-3 py-1 bg-bg-tertiary border border-border rounded
                                   text-text-secondary hover:text-accent-primary transition-colors"
                                            >
                                                → Push to BloodHound
                                            </button>
                                        )}
                                        {file === 'graph.json' && (
                                            <button
                                                onClick={() => onOpenInGraph(sessionId)}
                                                className="text-xs px-3 py-1 bg-accent-primary/20 border border-accent-primary/30 rounded
                                   text-accent-primary hover:bg-accent-primary/30 transition-colors"
                                            >
                                                📊 Open in Graph Visualiser
                                            </button>
                                        )}
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

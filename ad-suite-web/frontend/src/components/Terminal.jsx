import { useEffect, useRef } from 'react';

export function Terminal({ lines, isRunning, height = 320 }) {
    const endRef = useRef(null);

    // Auto-scroll to bottom on new lines
    useEffect(() => {
        if (isRunning) {
            endRef.current?.scrollIntoView({ behavior: 'smooth' });
        }
    }, [lines.length, isRunning]);

    return (
        <div className="rounded-xl border border-border overflow-hidden">
            <div className="flex items-center gap-2 px-4 py-2 bg-bg-primary border-b border-border">
                <span className="text-text-secondary text-xs font-mono">PowerShell Terminal</span>
                {isRunning && (
                    <span className="flex items-center gap-1 text-xs text-green-400">
                        <span className="w-1.5 h-1.5 bg-green-400 rounded-full animate-pulse" />
                        Live
                    </span>
                )}
                <span className="ml-auto text-text-muted text-xs">{lines.length} lines</span>
            </div>
            <div
                style={{ height, fontFamily: "'JetBrains Mono', monospace", fontSize: 12 }}
                className="bg-[#12100e] overflow-y-auto p-3 space-y-0.5"
            >
                {lines.length === 0 && (
                    <span className="text-text-muted">Waiting for output...</span>
                )}
                {lines.map((entry, i) => {
                    const line = typeof entry === 'string' ? entry : entry.line;

                    // Determine color based on content
                    let colour = 'text-gray-300';
                    if (line.startsWith('[ERR]') || line.includes('Error') || line.includes('FAIL') || line.includes('error'))
                        colour = 'text-red-400';
                    else if (line.includes('✓') || line.includes('Complete') || line.includes('Done'))
                        colour = 'text-green-400';
                    else if (line.includes('Starting') || line.includes('Running'))
                        colour = 'text-cyan-400';
                    else if (line.startsWith('[') && line.includes(']'))
                        colour = 'text-yellow-300';
                    else if (line.includes('finding'))
                        colour = 'text-blue-400';

                    return (
                        <div key={i} className={`${colour} leading-5 whitespace-pre-wrap break-words font-mono`}>
                            {line}
                        </div>
                    );
                })}
                <div ref={endRef} />
            </div>
        </div>
    );
}

export default Terminal;

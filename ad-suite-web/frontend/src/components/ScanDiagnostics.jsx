import { useState } from 'react';

const DEFAULT_CHECKS = [
    { category: 'Authentication', checkId: 'AUTH-001' },
    { category: 'Kerberos_Security', checkId: 'KRB-001' },
    { category: 'Access_Control', checkId: 'ACC-033' },
    { category: 'Domain_Controllers', checkId: 'DC-015' },
    { category: 'Service_Accounts', checkId: 'SVC-002' },
];

export function ScanDiagnostics({ suiteRoot, domain, targetServer }) {
    const [open, setOpen] = useState(false);
    const [running, setRunning] = useState(false);
    const [engine, setEngine] = useState('adsi');
    const [selCat, setSelCat] = useState(DEFAULT_CHECKS[0].category);
    const [selCheck, setSelCheck] = useState(DEFAULT_CHECKS[0].checkId);
    const [result, setResult] = useState(null);
    const [error, setError] = useState('');

    async function runDiagnostic() {
        setRunning(true);
        setResult(null);
        setError('');

        try {
            const params = new URLSearchParams({
                suiteRoot: suiteRoot || '',
                category: selCat,
                checkId: selCheck,
                engine,
                ...(domain ? { domain } : {}),
                ...(targetServer ? { targetServer } : {}),
            });

            const res = await fetch(`/api/scan/diagnose?${params}`);
            const data = await res.json();

            if (!res.ok) throw new Error(data.error || 'Diagnostic failed');
            setResult(data);
        } catch (err) {
            setError(err.message);
        } finally {
            setRunning(false);
        }
    }

    // Status colour helper
    function diagColour(diag) {
        if (!diag) return '#9b8e7e';
        if (diag.startsWith('SUCCESS')) return '#4e8c5f';
        if (diag.startsWith('NO_FINDINGS')) return '#5b7fa6';
        if (diag.startsWith('EMPTY_OUTPUT')) return '#d4a96a';
        return '#c0392b';
    }

    return (
        <div style={{
            border: '1px solid #3d3530',
            borderRadius: 8,
            marginBottom: 12,
            overflow: 'hidden',
            backgroundColor: '#1e1b18',
        }}>

            {/* Header bar */}
            <button
                onClick={() => setOpen(o => !o)}
                style={{
                    width: '100%', display: 'flex', alignItems: 'center', gap: 10,
                    padding: '10px 16px', background: 'none', border: 'none',
                    cursor: 'pointer', color: '#9b8e7e', fontSize: 13,
                    fontFamily: "'JetBrains Mono', monospace",
                }}
            >
                <span style={{ color: '#d4a96a', fontSize: 14 }}>🔬</span>
                <span style={{ fontWeight: 600, color: '#ede9e0' }}>Scan Diagnostics</span>
                <span style={{ fontSize: 11, color: '#6b5f54', flex: 1, textAlign: 'left' }}>
                    — verify scripts execute and produce real output
                </span>
                <span style={{ fontSize: 11 }}>{open ? '▲ Hide' : '▼ Show'}</span>
            </button>

            {/* Body */}
            {open && (
                <div style={{ padding: '0 16px 16px', borderTop: '1px solid #3d3530' }}>
                    <p style={{ fontSize: 12, color: '#6b5f54', margin: '10px 0 12px' }}>
                        Run a single check and inspect every step: path resolution, raw PowerShell
                        output, JSON parsing, and the final findings. Use this to confirm real scripts
                        execute before running a full scan.
                    </p>

                    {/* Controls */}
                    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>

                        {/* Check selector */}
                        <select
                            value={`${selCat}||${selCheck}`}
                            onChange={e => {
                                const [cat, chk] = e.target.value.split('||');
                                setSelCat(cat); setSelCheck(chk);
                            }}
                            style={selectStyle}
                        >
                            {DEFAULT_CHECKS.map(c => (
                                <option key={c.checkId} value={`${c.category}||${c.checkId}`}>
                                    {c.checkId.replace(/_/g, ' ')}
                                </option>
                            ))}
                        </select>

                        {/* Engine selector */}
                        <select value={engine} onChange={e => setEngine(e.target.value)} style={selectStyle}>
                            <option value="adsi">ADSI (adsi.ps1)</option>
                            <option value="powershell">PowerShell (powershell.ps1)</option>
                            <option value="combined">Combined (combined_multiengine.ps1)</option>
                        </select>

                        {/* Run button */}
                        <button
                            onClick={runDiagnostic}
                            disabled={running || !suiteRoot}
                            style={{
                                backgroundColor: running ? '#2d2926' : '#d4a96a',
                                color: running ? '#6b5f54' : '#1a1612',
                                border: 'none', borderRadius: 6,
                                padding: '6px 18px', fontSize: 13, fontWeight: 600,
                                cursor: running || !suiteRoot ? 'not-allowed' : 'pointer',
                                fontFamily: "'JetBrains Mono', monospace",
                            }}
                        >
                            {running ? '⏳ Running…' : '▶ Run Diagnostic'}
                        </button>

                        {!suiteRoot && (
                            <span style={{ fontSize: 11, color: '#c0392b', alignSelf: 'center' }}>
                                ⚠ Suite root path not set — go to Settings first
                            </span>
                        )}
                    </div>

                    {/* Error */}
                    {error && (
                        <div style={{ padding: '8px 12px', backgroundColor: '#2a1515', border: '1px solid #c0392b', borderRadius: 6, color: '#d45a47', fontSize: 12, marginBottom: 10 }}>
                            {error}
                        </div>
                    )}

                    {/* Results */}
                    {result && (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>

                            {/* Diagnosis banner */}
                            <div style={{
                                padding: '10px 14px',
                                backgroundColor: '#12100e',
                                border: `1px solid ${diagColour(result.diagnosis)}`,
                                borderRadius: 6,
                                borderLeft: `4px solid ${diagColour(result.diagnosis)}`,
                            }}>
                                <span style={{ fontSize: 12, color: diagColour(result.diagnosis), fontFamily: "'JetBrains Mono', monospace", fontWeight: 600 }}>
                                    {result.diagnosis}
                                </span>
                            </div>

                            {/* Stats row */}
                            <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
                                {[
                                    { label: 'Script found', value: result.scriptFound ? '✓ Yes' : '✗ No', ok: result.scriptFound },
                                    { label: 'Exit code', value: result.exitCode, ok: result.exitCode === 0 },
                                    { label: 'Duration', value: `${result.durationMs}ms`, ok: true },
                                    { label: 'Stdout bytes', value: result.stdoutLength, ok: result.stdoutLength > 0 },
                                    { label: 'Findings', value: result.findingCount, ok: result.findingCount >= 0 },
                                ].map(s => (
                                    <div key={s.label} style={{
                                        backgroundColor: '#262220', borderRadius: 6, padding: '6px 12px',
                                        border: `1px solid ${s.ok ? '#3d3530' : '#c0392b'}`,
                                    }}>
                                        <div style={{ fontSize: 10, color: '#6b5f54' }}>{s.label}</div>
                                        <div style={{ fontSize: 14, color: s.ok ? '#ede9e0' : '#c0392b', fontWeight: 600 }}>
                                            {String(s.value)}
                                        </div>
                                    </div>
                                ))}
                            </div>

                            {/* Script path */}
                            <div style={codeBlockStyle}>
                                <div style={codeLabelStyle}>Resolved script path</div>
                                <code style={codeStyle}>
                                    {result.scriptPath || '(not found)'}
                                </code>
                            </div>

                            {/* Raw stdout (first 2000 chars) */}
                            {result.stdoutRaw && (
                                <div style={codeBlockStyle}>
                                    <div style={codeLabelStyle}>
                                        Raw stdout ({result.stdoutLength} bytes total — showing first 2000)
                                    </div>
                                    <pre style={{ ...codeStyle, whiteSpace: 'pre-wrap', maxHeight: 200, overflowY: 'auto' }}>
                                        {result.stdoutRaw.slice(0, 2000)}
                                    </pre>
                                </div>
                            )}

                            {/* Stderr */}
                            {result.stderrRaw && (
                                <div style={{ ...codeBlockStyle, borderColor: '#5c2a1e' }}>
                                    <div style={{ ...codeLabelStyle, color: '#e07b39' }}>Stderr (warnings/errors)</div>
                                    <pre style={{ ...codeStyle, color: '#e07b39', whiteSpace: 'pre-wrap', maxHeight: 120, overflowY: 'auto' }}>
                                        {result.stderrRaw}
                                    </pre>
                                </div>
                            )}

                            {/* Parsed findings preview */}
                            {result.findings?.length > 0 && (
                                <div style={codeBlockStyle}>
                                    <div style={codeLabelStyle}>
                                        Parsed findings ({result.findingCount} total — showing first {Math.min(result.findings.length, 20)})
                                    </div>
                                    {result.findings.slice(0, 20).map((f, i) => (
                                        <div key={i} style={{
                                            padding: '4px 0', borderBottom: '1px solid #2d2926',
                                            fontSize: 12, color: '#ede9e0', fontFamily: "'JetBrains Mono', monospace",
                                        }}>
                                            <span style={{ color: '#d4a96a' }}>{f.name || f.checkName}</span>
                                            {f.distinguishedName && <span style={{ color: '#6b5f54' }}> — {f.distinguishedName}</span>}
                                        </div>
                                    ))}
                                </div>
                            )}

                            {/* What to do next */}
                            <div style={{ fontSize: 11, color: '#6b5f54', lineHeight: 1.6 }}>
                                {result.diagnosis?.startsWith('SUCCESS') && (
                                    <span style={{ color: '#4e8c5f' }}>
                                        ✓ Pipeline verified. You can now run a full scan and expect real findings.
                                    </span>
                                )}
                                {result.diagnosis?.startsWith('NO_FINDINGS') && (
                                    <span style={{ color: '#5b7fa6' }}>
                                        ✓ Script executed correctly. Zero findings = no vulnerable objects found for this check in your AD environment.
                                    </span>
                                )}
                                {result.diagnosis?.startsWith('EMPTY_OUTPUT') && (
                                    <span style={{ color: '#d4a96a' }}>
                                        ⚠ Script ran but returned no data. Confirm this machine is domain-joined and the current user has AD read access.
                                        Try: <code style={{ backgroundColor: '#1a1612', padding: '0 4px' }}>whoami /fqdn</code> in the PowerShell terminal.
                                    </span>
                                )}
                                {result.diagnosis?.startsWith('SCRIPT_NOT_FOUND') && (
                                    <span style={{ color: '#c0392b' }}>
                                        ✗ Script file not found. Go to Settings and verify the Suite Root Path points to AD-Suite-scripts-main/.
                                    </span>
                                )}
                                {result.diagnosis?.startsWith('SPAWN_FAILED') && (
                                    <span style={{ color: '#c0392b' }}>
                                        ✗ PowerShell could not start. Verify PowerShell 5.1+ is installed: open CMD and run <code>powershell -version</code>.
                                    </span>
                                )}
                            </div>

                        </div>
                    )}
                </div>
            )}
        </div>
    );
}

// Inline styles
const selectStyle = {
    backgroundColor: '#262220', border: '1px solid #3d3530',
    color: '#ede9e0', borderRadius: 6, padding: '6px 10px',
    fontSize: 12, fontFamily: "'JetBrains Mono', monospace",
    cursor: 'pointer',
};
const codeBlockStyle = {
    backgroundColor: '#12100e', border: '1px solid #3d3530',
    borderRadius: 6, padding: '8px 12px',
};
const codeLabelStyle = {
    fontSize: 10, color: '#6b5f54', marginBottom: 4,
    fontFamily: "'JetBrains Mono', monospace", textTransform: 'uppercase',
    letterSpacing: '0.05em',
};
const codeStyle = {
    fontSize: 11, color: '#9b8e7e',
    fontFamily: "'JetBrains Mono', 'Consolas', monospace",
    wordBreak: 'break-all', display: 'block', margin: 0,
};

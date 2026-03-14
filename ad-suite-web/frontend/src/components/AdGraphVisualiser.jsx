import { useEffect, useRef, useState, useCallback } from 'react';
import cytoscape from 'cytoscape';

const NODE_COLOURS = {
    User: '#5b7fa6',   // warm blue-grey
    Group: '#4e8c5f',   // warm forest green
    Computer: '#c47b3a',   // warm burnt orange
    Domain: '#8b6db5',   // warm muted purple
    OU: '#3d8c7a',   // warm teal
    Category: '#d4a96a',   // Claude accent amber
    Finding: '#c0392b',   // warm red
};

const LAYOUTS = {
    'Force-directed': { name: 'cose', animate: true, idealEdgeLength: 100, nodeOverlap: 20 },
    'Circle': { name: 'circle', animate: true },
    'Grid': { name: 'grid', animate: true },
    'Breadth-first': { name: 'breadthfirst', animate: true },
    'Concentric': { name: 'concentric', animate: true, minNodeSpacing: 50 },
};

export function AdGraphVisualiser({ preloadSessionId }) {
    const cyRef = useRef(null);
    const cyInstance = useRef(null);
    const [graphData, setGraphData] = useState(null);
    const [selected, setSelected] = useState(null);   // selected node data
    const [status, setStatus] = useState('idle');  // idle | loading | loaded | error
    const [error, setError] = useState('');
    const [layout, setLayout] = useState('Force-directed');
    const [filter, setFilter] = useState('All');
    const [dataSource, setDataSource] = useState('adexplorer');
    const [sessionId, setSessionId] = useState('');
    const [scanId, setScanId] = useState('');
    const [recentScans, setRecentScans] = useState([]);
    const [recentSessions, setRecentSessions] = useState([]);

    // Respond to "Open in Graph Visualiser" from ADExplorer section
    useEffect(() => {
        if (preloadSessionId) {
            setDataSource('adexplorer');
            setSessionId(preloadSessionId);
            loadGraph('adexplorer', preloadSessionId);
        }
    }, [preloadSessionId]);

    // Load recent scans for the dropdown
    useEffect(() => {
        fetch('/api/scan/recent')
            .then(r => r.json())
            .then(d => setRecentScans(d || []))
            .catch(() => { });
    }, []);

    // ── Initialise cytoscape when container is ready and data is loaded ──────
    useEffect(() => {
        if (!graphData || !cyRef.current) return;

        if (cyInstance.current) {
            cyInstance.current.destroy();
            cyInstance.current = null;
        }

        const elements = buildElements(graphData, filter);

        const cy = cytoscape({
            container: cyRef.current,
            elements,
            style: [
                {
                    selector: 'node',
                    style: {
                        'background-color': (el) => NODE_COLOURS[el.data('type')] || '#6b5f54',
                        'label': 'data(label)',
                        'color': '#ede9e0',
                        'font-size': '10px',
                        'font-family': "'JetBrains Mono', monospace",
                        'text-valign': 'bottom',
                        'text-halign': 'center',
                        'text-margin-y': 4,
                        'width': (el) => el.data('type') === 'Domain' ? 50 : 30,
                        'height': (el) => el.data('type') === 'Domain' ? 50 : 30,
                        'border-width': 2,
                        'border-color': (el) => NODE_COLOURS[el.data('type')] || '#6b5f54',
                        'border-opacity': 0.4,
                    },
                },
                {
                    selector: 'node:selected',
                    style: {
                        'border-width': 3,
                        'border-color': '#d4a96a',
                        'border-opacity': 1,
                    },
                },
                {
                    selector: 'edge',
                    style: {
                        'width': 1.5,
                        'line-color': '#4a403a',
                        'target-arrow-color': '#4a403a',
                        'target-arrow-shape': 'triangle',
                        'curve-style': 'bezier',
                        'label': 'data(label)',
                        'font-size': '8px',
                        'color': '#6b5f54',
                        'text-rotation': 'autorotate',
                    },
                },
                {
                    selector: 'edge:selected',
                    style: {
                        'line-color': '#d4a96a',
                        'target-arrow-color': '#d4a96a',
                    },
                },
            ],
            layout: LAYOUTS[layout],
        });

        // Click node → show properties panel
        cy.on('tap', 'node', (evt) => {
            const node = evt.target;
            setSelected({ id: node.id(), label: node.data('label'), type: node.data('type'), properties: node.data('properties') || {} });
        });

        // Click background → deselect
        cy.on('tap', (evt) => {
            if (evt.target === cy) setSelected(null);
        });

        cyInstance.current = cy;
    }, [graphData, filter, layout]);

    // ── Build cytoscape elements from graph data ──────────────────────────────
    function buildElements(data, typeFilter) {
        const nodes = data.nodes
            .filter(n => typeFilter === 'All' || n.type === typeFilter)
            .map(n => ({ data: { id: n.id, label: truncateLabel(n.label), type: n.type, properties: n.properties } }));

        const nodeIds = new Set(nodes.map(n => n.data.id));
        const edges = data.edges
            .filter(e => nodeIds.has(e.source) && nodeIds.has(e.target))
            .map(e => ({ data: { source: e.source, target: e.target, label: e.label || e.type, type: e.type } }));

        return [...nodes, ...edges];
    }

    function truncateLabel(label) {
        if (!label) return '';
        const atIdx = label.indexOf('@');
        const name = atIdx > 0 ? label.slice(0, atIdx) : label;
        return name.length > 20 ? name.slice(0, 18) + '…' : name;
    }

    // ── Load graph data ───────────────────────────────────────────────────────
    async function loadGraph(source, id) {
        if (!id) return;
        setStatus('loading');
        setSelected(null);
        setError('');

        try {
            const url = source === 'adexplorer'
                ? `/api/integrations/adexplorer/graph/${id}`
                : `/api/reports/graph-data/${id}`;

            const r = await fetch(url);
            if (!r.ok) throw new Error(`HTTP ${r.status}: ${await r.text()}`);
            const data = await r.json();

            if (!data.nodes || data.nodes.length === 0) {
                throw new Error('No nodes in graph data. Ensure the conversion completed successfully.');
            }

            setGraphData(data);
            setStatus('loaded');
        } catch (err) {
            setStatus('error');
            setError(err.message);
        }
    }

    // ── Layout change ─────────────────────────────────────────────────────────
    function applyLayout(layoutName) {
        setLayout(layoutName);
        if (!cyInstance.current) return;
        cyInstance.current.layout(LAYOUTS[layoutName]).run();
    }

    // ── Export PNG ────────────────────────────────────────────────────────────
    function exportPng() {
        if (!cyInstance.current) return;
        const png = cyInstance.current.png({ full: true, scale: 2, bg: '#12100e' });
        const a = document.createElement('a');
        a.href = png;
        a.download = 'ad-graph.png';
        a.click();
    }

    // ── Fit / zoom ────────────────────────────────────────────────────────────
    function fitGraph() { cyInstance.current?.fit(undefined, 30); }

    const nodeTypes = graphData
        ? ['All', ...new Set(graphData.nodes.map(n => n.type))]
        : ['All'];

    return (
        <div className="rounded-xl border border-border bg-bg-secondary overflow-hidden">

            {/* ── Section Header ─── */}
            <div className="p-4 border-b border-border">
                <h3 className="text-text-primary font-semibold">AD Graph Visualiser</h3>
                <p className="text-text-secondary text-sm mt-1">
                    Interactive node graph from ADExplorer snapshots or scan findings.
                    Separate from BloodHound — visualised entirely in-browser.
                </p>
            </div>

            {/* ── Data Source Selector ─── */}
            <div className="p-4 border-b border-border flex flex-wrap gap-3 items-end">
                <div className="flex gap-2">
                    <button
                        onClick={() => setDataSource('adexplorer')}
                        className={`text-sm px-3 py-1.5 rounded border transition-all ${dataSource === 'adexplorer'
                            ? 'bg-accent-muted border-accent-primary text-accent-primary'
                            : 'bg-bg-tertiary border-border text-text-secondary'
                            }`}
                    >
                        ADExplorer Session
                    </button>
                    <button
                        onClick={() => setDataSource('scan')}
                        className={`text-sm px-3 py-1.5 rounded border transition-all ${dataSource === 'scan'
                            ? 'bg-accent-muted border-accent-primary text-accent-primary'
                            : 'bg-bg-tertiary border-border text-text-secondary'
                            }`}
                    >
                        Scan Findings
                    </button>
                </div>

                {dataSource === 'adexplorer' ? (
                    <input
                        value={sessionId}
                        onChange={e => setSessionId(e.target.value)}
                        placeholder="ADExplorer session ID (paste or use [Open in Graph Visualiser])"
                        className="flex-1 bg-bg-primary border border-border rounded-lg px-3 py-1.5
                       text-text-primary text-sm font-mono placeholder:text-text-muted
                       focus:outline-none focus:border-accent-primary"
                    />
                ) : (
                    <select
                        value={scanId}
                        onChange={e => setScanId(e.target.value)}
                        className="flex-1 bg-bg-primary border border-border rounded-lg px-3 py-1.5
                       text-text-primary text-sm focus:outline-none focus:border-accent-primary"
                    >
                        <option value="">Select a scan…</option>
                        {recentScans.map(s => (
                            <option key={s.id} value={s.id}>
                                {new Date(s.timestamp).toLocaleString()} — {s.finding_count || 0} findings
                            </option>
                        ))}
                    </select>
                )}

                <button
                    onClick={() => loadGraph(dataSource, dataSource === 'adexplorer' ? sessionId : scanId)}
                    disabled={status === 'loading'}
                    className="bg-accent-primary hover:bg-accent-hover text-bg-primary font-medium
                     text-sm px-4 py-1.5 rounded-lg transition-all active:scale-95
                     disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    {status === 'loading' ? 'Loading…' : 'Load Graph'}
                </button>
            </div>

            {/* ── Graph Controls (only when loaded) ─── */}
            {status === 'loaded' && graphData && (
                <div className="px-4 py-2 border-b border-border bg-bg-primary flex flex-wrap gap-2 items-center">
                    <span className="text-text-muted text-xs">
                        {graphData.nodes.length} nodes · {graphData.edges.length} edges
                        {graphData.meta?.domain ? ` · ${graphData.meta.domain}` : ''}
                    </span>
                    <div className="flex-1" />

                    {/* Node type filter */}
                    <select
                        value={filter}
                        onChange={e => setFilter(e.target.value)}
                        className="bg-bg-secondary border border-border text-text-secondary text-xs
                       rounded px-2 py-1 focus:outline-none"
                    >
                        {nodeTypes.map(t => <option key={t}>{t}</option>)}
                    </select>

                    {/* Layout picker */}
                    <select
                        value={layout}
                        onChange={e => applyLayout(e.target.value)}
                        className="bg-bg-secondary border border-border text-text-secondary text-xs
                       rounded px-2 py-1 focus:outline-none"
                    >
                        {Object.keys(LAYOUTS).map(l => <option key={l}>{l}</option>)}
                    </select>

                    <button onClick={fitGraph} className="text-xs text-text-secondary hover:text-accent-primary bg-bg-tertiary border border-border rounded px-2 py-1">⊡ Fit</button>
                    <button onClick={exportPng} className="text-xs text-text-secondary hover:text-accent-primary bg-bg-tertiary border border-border rounded px-2 py-1">↓ PNG</button>
                </div>
            )}

            {/* ── Graph canvas + properties panel ─── */}
            <div className="flex" style={{ height: 520 }}>

                {/* Cytoscape container */}
                <div
                    ref={cyRef}
                    className="flex-1 bg-[#12100e]"
                    style={{ minWidth: 0 }}
                >
                    {/* Empty states */}
                    {status === 'idle' && (
                        <div className="flex items-center justify-center h-full text-text-muted text-sm">
                            Select a data source and click Load Graph
                        </div>
                    )}
                    {status === 'loading' && (
                        <div className="flex items-center justify-center h-full gap-3 text-text-secondary text-sm">
                            <div className="w-4 h-4 border-2 border-accent-primary border-t-transparent rounded-full animate-spin" />
                            Loading graph data…
                        </div>
                    )}
                    {status === 'error' && (
                        <div className="flex items-center justify-center h-full p-8 text-center">
                            <div className="text-red-400 text-sm">{error}</div>
                        </div>
                    )}
                </div>

                {/* Properties side panel — shown when a node is selected */}
                {selected && (
                    <div className="w-64 border-l border-border bg-bg-primary p-4 overflow-y-auto flex-shrink-0">
                        <div className="flex items-start justify-between mb-3">
                            <div>
                                <span
                                    className="text-xs px-2 py-0.5 rounded font-medium"
                                    style={{
                                        backgroundColor: (NODE_COLOURS[selected.type] || '#6b5f54') + '22',
                                        color: NODE_COLOURS[selected.type] || '#6b5f54',
                                    }}
                                >
                                    {selected.type}
                                </span>
                                <p className="text-text-primary text-sm font-medium mt-1 break-all">{selected.label}</p>
                            </div>
                            <button onClick={() => setSelected(null)} className="text-text-muted hover:text-text-primary ml-2">✕</button>
                        </div>

                        <div className="space-y-1.5">
                            {Object.entries(selected.properties || {}).map(([k, v]) => (
                                <div key={k} className="text-xs">
                                    <span className="text-text-muted">{k}: </span>
                                    <span className="text-text-secondary font-mono break-all">
                                        {typeof v === 'boolean' ? (v ? 'yes' : 'no') : String(v || '—')}
                                    </span>
                                </div>
                            ))}
                        </div>
                    </div>
                )}
            </div>

            {/* ── Legend ─── */}
            {status === 'loaded' && (
                <div className="px-4 py-2 border-t border-border bg-bg-primary flex flex-wrap gap-3">
                    {Object.entries(NODE_COLOURS).map(([type, colour]) => (
                        <div key={type} className="flex items-center gap-1.5 text-xs text-text-muted">
                            <span className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ backgroundColor: colour }} />
                            {type}
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}

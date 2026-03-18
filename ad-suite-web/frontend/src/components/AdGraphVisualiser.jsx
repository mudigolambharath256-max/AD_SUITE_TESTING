import { useEffect, useRef, useState, useCallback } from 'react';
import cytoscape from 'cytoscape';

const NODE_COLOURS = {
    User: '#5b7fa6',       // warm blue-grey (BloodHound style)
    Group: '#4e8c5f',      // warm forest green
    Computer: '#c47b3a',   // warm burnt orange
    Domain: '#8b6db5',     // warm muted purple
    OU: '#3d8c7a',         // warm teal
    GPO: '#9b59b6',        // purple for Group Policy Objects
    Category: '#d4a96a',   // Claude accent amber
    Finding: '#c0392b',    // warm red
    ATTACKER: '#e74c3c',   // bright red for attack nodes
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
    const [dataSource, setDataSource] = useState('bloodhound');
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
                        'width': (el) => {
                            const type = el.data('type');
                            if (type === 'Domain') return 60;
                            if (type === 'Computer') return 35;
                            if (type === 'Group') return 30;
                            return 25; // User default
                        },
                        'height': (el) => {
                            const type = el.data('type');
                            if (type === 'Domain') return 60;
                            if (type === 'Computer') return 35;
                            if (type === 'Group') return 30;
                            return 25; // User default
                        },
                        'shape': (el) => {
                            const type = el.data('type');
                            if (type === 'User') return 'ellipse';
                            if (type === 'Computer') return 'rectangle';
                            if (type === 'Group') return 'hexagon';
                            if (type === 'Domain') return 'star';
                            if (type === 'OU') return 'triangle';
                            if (type === 'GPO') return 'diamond';
                            return 'ellipse';
                        },
                        'border-width': 2,
                        'border-color': (el) => {
                            const props = el.data('properties') || {};
                            // Highlight high-value targets
                            if (props.adSuiteSeverity === 'CRITICAL') return '#e74c3c';
                            if (props.adSuiteSeverity === 'HIGH') return '#f39c12';
                            if (props.isACLProtected || props.admincount) return '#d4a96a';
                            return NODE_COLOURS[el.data('type')] || '#6b5f54';
                        },
                        'border-opacity': (el) => {
                            const props = el.data('properties') || {};
                            if (props.adSuiteSeverity === 'CRITICAL' || props.adSuiteSeverity === 'HIGH') return 1;
                            return 0.4;
                        },
                    },
                },
                {
                    selector: 'node:selected',
                    style: {
                        'border-width': 4,
                        'border-color': '#d4a96a',
                        'border-opacity': 1,
                    },
                },
                {
                    selector: 'edge',
                    style: {
                        'width': (el) => {
                            const type = el.data('type');
                            if (type === 'attack') return 3;
                            if (type === 'membership') return 2;
                            return 1.5;
                        },
                        'line-color': (el) => {
                            const type = el.data('type');
                            if (type === 'attack') return '#e74c3c';
                            if (type === 'membership') return '#3498db';
                            return '#4a403a';
                        },
                        'target-arrow-color': (el) => {
                            const type = el.data('type');
                            if (type === 'attack') return '#e74c3c';
                            if (type === 'membership') return '#3498db';
                            return '#4a403a';
                        },
                        'target-arrow-shape': 'triangle',
                        'curve-style': 'bezier',
                        'label': 'data(label)',
                        'font-size': '8px',
                        'color': '#6b5f54',
                        'text-rotation': 'autorotate',
                        'line-style': (el) => {
                            const type = el.data('type');
                            if (type === 'attack') return 'dashed';
                            return 'solid';
                        },
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
        // Handle BloodHound format data
        if (data.nodes && data.nodes[0]?.ObjectIdentifier) {
            return buildBloodHoundElements(data, typeFilter);
        }

        // Handle legacy format data
        const nodes = data.nodes
            .filter(n => typeFilter === 'All' || n.type === typeFilter)
            .map(n => ({
                data: {
                    id: n.id,
                    label: truncateLabel(n.label),
                    type: n.type,
                    properties: n.properties
                }
            }));

        const nodeIds = new Set(nodes.map(n => n.data.id));
        const edges = data.edges
            .filter(e => nodeIds.has(e.source) && nodeIds.has(e.target))
            .map(e => ({
                data: {
                    source: e.source,
                    target: e.target,
                    label: e.label || e.type,
                    type: e.type
                }
            }));

        return [...nodes, ...edges];
    }

    // Build elements from BloodHound format data
    function buildBloodHoundElements(data, typeFilter) {
        const nodes = data.nodes
            .filter(n => {
                const nodeType = getNodeType(n);
                return typeFilter === 'All' || nodeType === typeFilter;
            })
            .map(n => {
                const nodeType = getNodeType(n);
                const label = getNodeLabel(n);

                return {
                    data: {
                        id: n.ObjectIdentifier,
                        label: truncateLabel(label),
                        type: nodeType,
                        properties: {
                            ...n.Properties,
                            objectIdentifier: n.ObjectIdentifier,
                            isDeleted: n.IsDeleted,
                            isACLProtected: n.IsACLProtected
                        }
                    }
                };
            });

        const nodeIds = new Set(nodes.map(n => n.data.id));
        const edges = data.edges
            .filter(e => nodeIds.has(e.source) && nodeIds.has(e.target))
            .map(e => ({
                data: {
                    source: e.source,
                    target: e.target,
                    label: e.label || e.type,
                    type: e.type || 'relationship'
                }
            }));

        return [...nodes, ...edges];
    }

    // Get node type from BloodHound node
    function getNodeType(node) {
        if (node.Labels && node.Labels.length > 0) {
            return node.Labels[0];
        }

        // Fallback to properties-based detection
        const props = node.Properties || {};
        if (props.samaccountname && props.samaccountname.endsWith('$')) return 'Computer';
        if (props.distinguishedname && props.distinguishedname.includes('CN=Groups')) return 'Group';
        if (props.distinguishedname && props.distinguishedname.startsWith('OU=')) return 'OU';
        if (props.distinguishedname && props.distinguishedname.startsWith('DC=')) return 'Domain';

        return 'User'; // Default
    }

    // Get display label for BloodHound node
    function getNodeLabel(node) {
        const props = node.Properties || {};

        // Use name property if available
        if (props.name) {
            // Remove domain suffix for cleaner display
            const atIndex = props.name.indexOf('@');
            return atIndex > 0 ? props.name.substring(0, atIndex) : props.name;
        }

        // Fallback to samaccountname or CN from DN
        if (props.samaccountname) return props.samaccountname;

        if (props.distinguishedname) {
            const cnMatch = props.distinguishedname.match(/CN=([^,]+)/);
            if (cnMatch) return cnMatch[1];
        }

        return node.ObjectIdentifier || 'Unknown';
    }

    function truncateLabel(label) {
        if (!label) return '';
        const atIdx = label.indexOf('@');
        const name = atIdx > 0 ? label.slice(0, atIdx) : label;
        return name.length > 20 ? name.slice(0, 18) + '…' : name;
    }

    // ── Load graph data ───────────────────────────────────────────────────────
    async function loadGraph(source, id) {
        if (!id && source !== 'demo') return;
        setStatus('loading');
        setSelected(null);
        setError('');

        try {
            let url;

            switch (source) {
                case 'demo':
                    url = `/api/bloodhound/demo`;
                    break;
                case 'bloodhound':
                    url = `/api/bloodhound/scan/${id}`;
                    break;
                case 'findings':
                    url = `/api/bloodhound/findings/${id}`;
                    break;
                case 'adexplorer':
                    url = `/api/integrations/adexplorer/graph/${id}`;
                    break;
                default:
                    url = `/api/reports/graph-data/${id}`;
            }

            const r = await fetch(url);
            if (!r.ok) throw new Error(`HTTP ${r.status}: ${await r.text()}`);
            const data = await r.json();

            if (!data.nodes || data.nodes.length === 0) {
                throw new Error('No nodes in graph data. Run a scan first or ensure BloodHound export is enabled.');
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
        ? ['All', ...new Set(graphData.nodes.map(n => {
            // Handle BloodHound format
            if (n.ObjectIdentifier) {
                return getNodeType(n);
            }
            // Handle legacy format
            return n.type;
        }))]
        : ['All'];

    return (
        <div className="rounded-xl border border-border bg-bg-secondary overflow-hidden">

            {/* ── Section Header ─── */}
            <div className="p-4 border-b border-border">
                <h3 className="text-text-primary font-semibold">AD Graph Visualiser</h3>
                <p className="text-text-secondary text-sm mt-1">
                    Interactive BloodHound-style visualization of Active Directory objects (Users, Computers, Groups)
                    from scan findings or BloodHound exports. Shows actual AD relationships and attack paths.
                </p>
            </div>

            {/* ── Data Source Selector ─── */}
            <div className="p-4 border-b border-border flex flex-wrap gap-3 items-end">
                <div className="flex gap-2">
                    <button
                        onClick={() => setDataSource('bloodhound')}
                        className={`text-sm px-3 py-1.5 rounded border transition-all ${dataSource === 'bloodhound'
                            ? 'bg-accent-muted border-accent-primary text-accent-primary'
                            : 'bg-bg-tertiary border-border text-text-secondary'
                            }`}
                    >
                        BloodHound Export
                    </button>
                    <button
                        onClick={() => setDataSource('findings')}
                        className={`text-sm px-3 py-1.5 rounded border transition-all ${dataSource === 'findings'
                            ? 'bg-accent-muted border-accent-primary text-accent-primary'
                            : 'bg-bg-tertiary border-border text-text-secondary'
                            }`}
                    >
                        Scan Findings
                    </button>
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
                        onClick={() => {
                            setDataSource('demo');
                            loadGraph('demo', null);
                        }}
                        className="text-sm px-3 py-1.5 rounded border transition-all bg-green-600 hover:bg-green-700 border-green-500 text-white"
                    >
                        Demo Data
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
                ) : dataSource === 'demo' ? (
                    <div className="flex-1 text-sm text-text-secondary italic">
                        Click "Demo Data" to load sample BloodHound visualization
                    </div>
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

                {dataSource !== 'demo' && (
                    <button
                        onClick={() => loadGraph(dataSource, dataSource === 'adexplorer' ? sessionId : scanId)}
                        disabled={status === 'loading'}
                        className="bg-accent-primary hover:bg-accent-hover text-bg-primary font-medium
                         text-sm px-4 py-1.5 rounded-lg transition-all active:scale-95
                         disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        {status === 'loading' ? 'Loading…' : 'Load Graph'}
                    </button>
                )}
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
                            Select BloodHound Export or Scan Findings and click Load Graph
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
                            {/* Show BloodHound-specific properties first */}
                            {selected.properties?.adSuiteCheckId && (
                                <div className="mb-3 p-2 bg-bg-secondary rounded border">
                                    <div className="text-xs text-text-muted mb-1">Security Finding</div>
                                    <div className="text-xs">
                                        <span className="text-text-muted">Check: </span>
                                        <span className="text-text-secondary font-mono">{selected.properties.adSuiteCheckId}</span>
                                    </div>
                                    <div className="text-xs">
                                        <span className="text-text-muted">Severity: </span>
                                        <span className={`font-mono ${selected.properties.adSuiteSeverity === 'CRITICAL' ? 'text-red-400' :
                                            selected.properties.adSuiteSeverity === 'HIGH' ? 'text-orange-400' :
                                                selected.properties.adSuiteSeverity === 'MEDIUM' ? 'text-yellow-400' :
                                                    'text-text-secondary'
                                            }`}>
                                            {selected.properties.adSuiteSeverity}
                                        </span>
                                    </div>
                                    {selected.properties.adSuiteMitre && (
                                        <div className="text-xs">
                                            <span className="text-text-muted">MITRE: </span>
                                            <span className="text-text-secondary font-mono">{selected.properties.adSuiteMitre}</span>
                                        </div>
                                    )}
                                </div>
                            )}

                            {/* Core AD properties */}
                            {selected.properties?.samaccountname && (
                                <div className="text-xs">
                                    <span className="text-text-muted">SAM Account: </span>
                                    <span className="text-text-secondary font-mono break-all">{selected.properties.samaccountname}</span>
                                </div>
                            )}

                            {selected.properties?.domain && (
                                <div className="text-xs">
                                    <span className="text-text-muted">Domain: </span>
                                    <span className="text-text-secondary font-mono break-all">{selected.properties.domain}</span>
                                </div>
                            )}

                            {selected.properties?.enabled !== undefined && (
                                <div className="text-xs">
                                    <span className="text-text-muted">Enabled: </span>
                                    <span className={`font-mono ${selected.properties.enabled ? 'text-green-400' : 'text-red-400'}`}>
                                        {selected.properties.enabled ? 'Yes' : 'No'}
                                    </span>
                                </div>
                            )}

                            {selected.properties?.isACLProtected && (
                                <div className="text-xs">
                                    <span className="text-text-muted">ACL Protected: </span>
                                    <span className="text-yellow-400 font-mono">Yes</span>
                                </div>
                            )}

                            {/* Distinguished Name */}
                            {selected.properties?.distinguishedname && (
                                <div className="text-xs">
                                    <span className="text-text-muted">DN: </span>
                                    <span className="text-text-secondary font-mono break-all text-xs">{selected.properties.distinguishedname}</span>
                                </div>
                            )}

                            {/* All other properties */}
                            {Object.entries(selected.properties || {})
                                .filter(([k]) => !['adSuiteCheckId', 'adSuiteSeverity', 'adSuiteMitre', 'samaccountname', 'domain', 'enabled', 'isACLProtected', 'distinguishedname'].includes(k))
                                .map(([k, v]) => (
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
                <div className="px-4 py-2 border-t border-border bg-bg-primary">
                    <div className="flex flex-wrap gap-3 mb-2">
                        <div className="text-xs text-text-muted font-medium">Node Types:</div>
                        {Object.entries(NODE_COLOURS).map(([type, colour]) => (
                            <div key={type} className="flex items-center gap-1.5 text-xs text-text-muted">
                                <span
                                    className="w-2.5 h-2.5 flex-shrink-0"
                                    style={{
                                        backgroundColor: colour,
                                        borderRadius: type === 'User' ? '50%' :
                                            type === 'Computer' ? '0' :
                                                type === 'Group' ? '0' : '50%'
                                    }}
                                />
                                {type}
                            </div>
                        ))}
                    </div>
                    <div className="flex flex-wrap gap-3 text-xs text-text-muted">
                        <div className="flex items-center gap-1.5">
                            <div className="w-2 h-0.5 bg-red-400"></div>
                            Attack Path
                        </div>
                        <div className="flex items-center gap-1.5">
                            <div className="w-2 h-0.5 bg-blue-400"></div>
                            Membership
                        </div>
                        <div className="flex items-center gap-1.5">
                            <div className="w-2 h-0.5 bg-gray-400"></div>
                            Relationship
                        </div>
                        <div className="flex items-center gap-1.5">
                            <div className="w-2.5 h-2.5 border-2 border-yellow-400 rounded-full"></div>
                            High-Value Target
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

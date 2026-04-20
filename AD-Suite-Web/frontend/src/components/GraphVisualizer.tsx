import { useEffect, useRef } from 'react';
import Graph from 'graphology';
import Sigma from 'sigma';
import circular from 'graphology-layout/circular';
import forceAtlas2 from 'graphology-layout-forceatlas2';

export interface GraphVisualizerData {
    nodes: {
        id: string;
        label: string;
        color?: string;
        size?: number;
        type?: string;
        maxSeverity?: string;
    }[];
    edges: {
        id: string;
        source: string;
        target: string;
        label?: string;
        color?: string;
        relation?: string;
        severity?: string;
    }[];
}

interface GraphVisualizerProps {
    data: GraphVisualizerData;
}

const NODE_COLORS: Record<string, string> = {
    User: '#378ADD',
    Group: '#1D9E75',
    Computer: '#F0A500',
    Domain: '#E24B4A',
    GPO: '#888780',
    ADCS: '#D4537E',
    CA: '#D4537E',
    Template: '#9b87f5',
    OU: '#38bdf8',
    Other: '#64748b'
};

const EDGE_COLORS: Record<string, string> = {
    MemberOf: '#4a4a6a',
    HasRBCD: '#9B59B6',
    'AllowedToAct(RBCD)': '#9B59B6',
    CanKerberoast: '#E67E22',
    Kerberoast: '#E67E22',
    UnconstrainedDelegation: '#E24B4A',
    DCSync: '#E24B4A',
    CanASREPRoast: '#E67E22',
    ASREPRoast: '#E67E22',
    HasSIDHistory: '#F0A500',
    AppliesTo: '#2ECC71',
    LinkedTo: '#2ECC71',
    SameFinding: '#4a4a5a',
    InScope: '#3d3d4a',
    HasSPN: '#E67E22',
    HasShadowCredentials: '#E24B4A',
    'ProtectedUser(adminCount=1)': '#F0A500',
    ReversibleEncryptionEnabled: '#E67E22',
    Enroll: '#2ECC71',
    PublishedBy: '#D4537E',
    default: '#4a4a5a'
};

function edgeColorForRelation(relation: string): string {
    if (EDGE_COLORS[relation]) return EDGE_COLORS[relation];
    const r = relation.toLowerCase();
    if (r.includes('rbcd') || r.includes('allowedtoact')) return EDGE_COLORS['AllowedToAct(RBCD)'];
    if (r.includes('dcsync')) return EDGE_COLORS.DCSync;
    if (r.includes('kerberoast')) return EDGE_COLORS.Kerberoast;
    if (r.includes('asrep')) return EDGE_COLORS.ASREPRoast;
    if (r.includes('shadow')) return EDGE_COLORS.HasShadowCredentials;
    return EDGE_COLORS.default;
}

function edgeSizeForSeverity(severity: string | undefined): number {
    const s = (severity || 'low').toLowerCase();
    if (s === 'critical' || s === 'crit') return 2.5;
    if (s === 'high') return 1.5;
    return 0.8;
}

const LEGEND = [
    { color: '#378ADD', label: 'User' },
    { color: '#1D9E75', label: 'Group' },
    { color: '#F0A500', label: 'Computer' },
    { color: '#E24B4A', label: 'Domain / DC' },
    { color: '#888780', label: 'GPO' },
    { color: '#D4537E', label: 'ADCS / CA' }
];

const EDGE_LEGEND = [
    { color: '#E24B4A', label: 'Critical / DCSync' },
    { color: '#E67E22', label: 'Kerberos attack' },
    { color: '#9B59B6', label: 'RBCD / delegation' },
    { color: '#4a4a6a', label: 'Membership' }
];

export function GraphVisualizer({ data }: GraphVisualizerProps) {
    const containerRef = useRef<HTMLDivElement>(null);
    const hasData = Boolean(data?.nodes?.length);

    useEffect(() => {
        const el = containerRef.current;
        if (!el || !hasData || !data.nodes?.length) return;

        const graph = new Graph({ multi: true, type: 'directed' });

        for (const n of data.nodes) {
            if (graph.hasNode(n.id)) continue;
            graph.addNode(n.id, {
                label: n.label ?? n.id,
                color: NODE_COLORS[n.type ?? 'User'] ?? n.color ?? '#378ADD',
                size: 8,
                type: n.type ?? 'User',
                maxSeverity: n.maxSeverity ?? 'info'
            });
        }

        for (const e of data.edges) {
            if (!graph.hasNode(e.source) || !graph.hasNode(e.target)) continue;
            const relation =
                e.relation?.trim() ||
                (e.label && e.label.includes(' (') ? e.label.split(' (')[0] : e.label) ||
                '';
            const color = e.color ?? edgeColorForRelation(relation);
            const size = edgeSizeForSeverity(e.severity);
            if (!graph.hasEdge(e.id)) {
                graph.addEdgeWithKey(e.id, e.source, e.target, {
                    type: 'arrow',
                    label: e.label ?? '',
                    color,
                    size,
                    relation
                });
            }
        }

        graph.forEachNode((node) => {
            const deg = graph.degree(node);
            const type = graph.getNodeAttribute(node, 'type') as string;
            const baseColor = NODE_COLORS[type] ?? NODE_COLORS.User;
            graph.setNodeAttribute(node, 'color', baseColor);
            const size =
                type === 'Domain'
                    ? 22
                    : type === 'Group'
                      ? Math.max(10, 6 + deg * 2)
                      : Math.max(6, 4 + deg * 2);
            graph.setNodeAttribute(node, 'size', size);
        });

        circular.assign(graph);

        forceAtlas2.assign(graph, {
            iterations: 500,
            settings: {
                scalingRatio: 30,
                gravity: 0.05,
                slowDown: 5,
                linLogMode: true,
                adjustSizes: true,
                barnesHutOptimize: true,
                barnesHutTheta: 0.5,
                outboundAttractionDistribution: true,
                edgeWeightInfluence: 1,
                strongGravityMode: false
            }
        });

        const renderer = new Sigma(graph, el, {
            renderLabels: true,
            labelSize: 11,
            labelWeight: '400',
            labelColor: { color: '#cccccc' },
            labelDensity: 0.1,
            labelGridCellSize: 80,
            defaultEdgeType: 'arrow',
            renderEdgeLabels: false,
            hideEdgesOnMove: false,
            hideLabelsOnMove: false,
            minCameraRatio: 0.05,
            maxCameraRatio: 10
        });

        return () => {
            renderer.kill();
        };
    }, [data, hasData]);

    if (!hasData) {
        return (
            <div
                style={{ height: '120px', width: '100%' }}
                className="bg-gray-900 rounded-lg border border-gray-700 mt-4 flex items-center justify-center text-sm text-gray-500"
            >
                No graph nodes for this scan (no entity-shaped findings matched).
            </div>
        );
    }

    return (
        <div style={{ position: 'relative', width: '100%', height: '100%' }}>
            <div
                ref={containerRef}
                style={{ width: '100%', height: '100%', background: '#111116' }}
            />

            <div
                style={{
                    position: 'absolute',
                    bottom: 16,
                    left: 16,
                    background: 'rgba(10,10,16,0.88)',
                    borderRadius: 8,
                    padding: '10px 14px',
                    display: 'flex',
                    flexDirection: 'column',
                    gap: 5,
                    zIndex: 20,
                    border: '0.5px solid rgba(255,255,255,0.08)',
                    pointerEvents: 'none'
                }}
            >
                <span
                    style={{
                        fontSize: 9,
                        color: '#666',
                        letterSpacing: '0.06em',
                        marginBottom: 2
                    }}
                >
                    NODE TYPE
                </span>
                {LEGEND.map(({ color, label }) => (
                    <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                        <div
                            style={{
                                width: 10,
                                height: 10,
                                borderRadius: '50%',
                                background: color,
                                flexShrink: 0
                            }}
                        />
                        <span style={{ fontSize: 11, color: '#bbb' }}>{label}</span>
                    </div>
                ))}
                <span
                    style={{
                        fontSize: 9,
                        color: '#666',
                        letterSpacing: '0.06em',
                        margin: '6px 0 2px'
                    }}
                >
                    EDGE TYPE
                </span>
                {EDGE_LEGEND.map(({ color, label }) => (
                    <div key={label} style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                        <div
                            style={{
                                width: 16,
                                height: 2,
                                background: color,
                                flexShrink: 0,
                                borderRadius: 1
                            }}
                        />
                        <span style={{ fontSize: 11, color: '#bbb' }}>{label}</span>
                    </div>
                ))}
            </div>

            <div
                style={{
                    position: 'absolute',
                    top: 12,
                    left: 12,
                    background: 'rgba(10,10,16,0.7)',
                    borderRadius: 6,
                    padding: '4px 10px',
                    fontSize: 11,
                    color: '#888',
                    zIndex: 20,
                    pointerEvents: 'none',
                    border: '0.5px solid rgba(255,255,255,0.06)'
                }}
            >
                {data.nodes.length} nodes · {data.edges.length} edges
            </div>
        </div>
    );
}

export default GraphVisualizer;

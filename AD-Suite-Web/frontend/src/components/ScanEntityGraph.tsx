import { useEffect, useMemo, useRef, useState } from 'react';
import cytoscape, { type Core } from 'cytoscape';
import type { EntityGraph, NodeFindingRef } from '../lib/extractEntityGraph';

type Props = {
    graph: EntityGraph;
    /** When true, graph panel fills available space (e.g. browser fullscreen). */
    isFullscreen?: boolean;
};

function colorForKind(kind: string): string {
    switch (kind) {
        case 'User':
            return '#60a5fa';
        case 'Computer':
            return '#34d399';
        case 'Group':
            return '#fbbf24';
        case 'Template':
            return '#a78bfa';
        case 'CA':
            return '#f472b6';
        case 'GPO':
            return '#fb7185';
        case 'OU':
            return '#38bdf8';
        case 'Domain':
            return '#e2e8f0';
        default:
            return '#94a3b8';
    }
}

const SEV_ORDER: Record<string, number> = {
    critical: 0,
    high: 1,
    medium: 2,
    low: 3,
    info: 4
};

function severityRank(s: string | undefined): number {
    if (!s) return 99;
    return SEV_ORDER[s.toLowerCase()] ?? 50;
}

function sortFindings(refs: NodeFindingRef[]): NodeFindingRef[] {
    return [...refs].sort((a, b) => {
        const ra = severityRank(a.severity);
        const rb = severityRank(b.severity);
        if (ra !== rb) return ra - rb;
        return a.checkId.localeCompare(b.checkId);
    });
}

export default function ScanEntityGraph({ graph, isFullscreen = false }: Props) {
    const containerRef = useRef<HTMLDivElement | null>(null);
    const cyRef = useRef<Core | null>(null);
    const [selected, setSelected] = useState<{
        type: 'node' | 'edge';
        nodeId?: string;
        data: Record<string, unknown>;
    } | null>(null);

    const findingsByNodeId = graph.findingsByNodeId ?? {};

    const elements = useMemo(() => {
        const nodes = graph.nodes.map((n) => ({
            data: { id: n.id, label: n.label, kind: n.kind }
        }));
        const edges = graph.edges.map((e) => ({
            data: {
                id: e.id,
                source: e.from,
                target: e.to,
                label: `${e.rel} (${e.findingId})`,
                rel: e.rel,
                findingId: e.findingId,
                evidence: e.evidence || null
            }
        }));
        return [...nodes, ...edges];
    }, [graph]);

    useEffect(() => {
        if (!containerRef.current) return;
        if (cyRef.current) {
            cyRef.current.destroy();
            cyRef.current = null;
        }

        const cy = cytoscape({
            container: containerRef.current,
            elements,
            style: [
                {
                    selector: 'node',
                    style: {
                        label: 'data(label)',
                        color: '#e5e7eb',
                        'font-size': 10,
                        'text-wrap': 'wrap',
                        'text-max-width': '140px',
                        'text-valign': 'center',
                        'text-halign': 'center',
                        'background-color': (ele) => colorForKind(ele.data('kind')),
                        'border-width': 1,
                        'border-color': '#0f172a',
                        width: '42px',
                        height: '42px'
                    }
                },
                {
                    selector: 'edge',
                    style: {
                        width: '2px',
                        'curve-style': 'bezier',
                        'target-arrow-shape': 'triangle',
                        'line-color': '#64748b',
                        'target-arrow-color': '#64748b',
                        label: 'data(label)',
                        'font-size': 9,
                        color: '#cbd5e1',
                        'text-background-color': '#0b1220',
                        'text-background-opacity': 0.85,
                        'text-background-padding': '2px',
                        'text-rotation': 'autorotate'
                    }
                },
                {
                    selector: ':selected',
                    style: {
                        'border-width': 3,
                        'border-color': '#f97316',
                        'line-color': '#f97316',
                        'target-arrow-color': '#f97316'
                    }
                }
            ],
            layout: {
                name: 'cose',
                animate: true,
                gravity: 1.1,
                nodeRepulsion: 9000,
                idealEdgeLength: 120,
                edgeElasticity: 0.3
            } as any
        });

        cy.on('tap', 'edge', (evt) => {
            setSelected({ type: 'edge', data: evt.target.data() });
        });
        cy.on('tap', 'node', (evt) => {
            const nodeId = evt.target.id();
            setSelected({ type: 'node', nodeId, data: evt.target.data() });
        });
        cy.on('tap', (evt) => {
            if (evt.target === cy) setSelected(null);
        });

        cyRef.current = cy;
        return () => cy.destroy();
    }, [elements]);

    useEffect(() => {
        const cy = cyRef.current;
        if (!cy) return;
        const t = window.setTimeout(() => {
            cy.resize();
            cy.fit(undefined, 40);
        }, 120);
        return () => window.clearTimeout(t);
    }, [isFullscreen]);

    const nodeFindingsSorted = useMemo(() => {
        if (selected?.type !== 'node' || !selected.nodeId) return [];
        const raw = findingsByNodeId[selected.nodeId];
        if (!raw?.length) return [];
        return sortFindings(raw);
    }, [selected, findingsByNodeId]);

    return (
        <div
            className={
                isFullscreen
                    ? 'flex flex-col lg:flex-row flex-1 min-h-0 gap-4'
                    : 'grid grid-cols-1 lg:grid-cols-12 gap-4'
            }
        >
            <div
                className={
                    isFullscreen
                        ? 'flex-1 min-h-0 flex flex-col bg-bg-tertiary border border-border-medium rounded-xl overflow-hidden'
                        : 'lg:col-span-9 bg-bg-tertiary border border-border-medium rounded-xl overflow-hidden min-h-[520px]'
                }
            >
                <div
                    ref={containerRef}
                    className={
                        isFullscreen ? 'w-full h-[min(78vh,920px)]' : 'w-full h-[520px]'
                    }
                />
            </div>
            <div
                className={
                    isFullscreen
                        ? 'lg:w-[min(100%,380px)] shrink-0 flex flex-col bg-surface-elevated border border-border-light rounded-xl p-4 max-h-[min(78vh,920px)] overflow-hidden'
                        : 'lg:col-span-3 bg-surface-elevated border border-border-light rounded-xl p-4 flex flex-col max-h-[520px]'
                }
            >
                <div className="text-sm font-medium text-text-primary mb-2 shrink-0">Selection</div>
                {!selected ? (
                    <div className="text-sm text-text-tertiary">
                        Click a node or edge. For nodes, check findings and full row data appear below.
                    </div>
                ) : selected.type === 'node' ? (
                    <div className="space-y-3 text-sm min-h-0 flex flex-col flex-1 overflow-hidden">
                        <div className="shrink-0 space-y-1">
                            <div className="text-text-secondary text-xs uppercase tracking-wide">Entity</div>
                            <div className="text-text-primary font-medium">{String(selected.data.kind ?? '')}</div>
                            <div className="text-text-primary font-mono text-xs break-words">{String(selected.data.label ?? '')}</div>
                        </div>
                        <div className="border-t border-border-light pt-3 flex flex-col flex-1 min-h-0 overflow-hidden">
                            <div className="text-text-secondary text-xs uppercase tracking-wide mb-2 shrink-0">
                                Checks / findings affecting this entity
                            </div>
                            {nodeFindingsSorted.length === 0 ? (
                                <p className="text-text-tertiary text-xs">
                                    No finding rows indexed for this node (unsupported check type or no matching fields).
                                </p>
                            ) : (
                                <ul className="space-y-3 overflow-y-auto pr-1 flex-1">
                                    {nodeFindingsSorted.map((ref, idx) => (
                                        <li
                                            key={`${ref.checkId}-${idx}-${ref.edgeSummary ?? ''}`}
                                            className="rounded-lg border border-border-medium bg-bg-tertiary/50 p-2.5 text-xs"
                                        >
                                            <div className="flex flex-wrap gap-1.5 mb-2">
                                                <span className="font-mono font-semibold text-accent-orange">{ref.checkId}</span>
                                                {ref.severity && (
                                                    <span className="px-1.5 py-0.5 rounded bg-bg-secondary text-text-secondary capitalize">
                                                        {ref.severity}
                                                    </span>
                                                )}
                                                {ref.edgeSummary && (
                                                    <span className="text-text-tertiary truncate max-w-full" title={ref.edgeSummary}>
                                                        {ref.edgeSummary}
                                                    </span>
                                                )}
                                            </div>
                                            {ref.checkName && (
                                                <div className="text-text-primary font-medium mb-1">{ref.checkName}</div>
                                            )}
                                            {ref.category && (
                                                <div className="text-text-tertiary mb-2">{ref.category}</div>
                                            )}
                                            <div className="text-text-secondary mb-1">Finding data</div>
                                            <pre className="text-[11px] leading-relaxed bg-bg-secondary border border-border-medium rounded-md p-2 overflow-x-auto max-h-40 text-text-secondary whitespace-pre-wrap break-words">
                                                {JSON.stringify(ref.fields, null, 2)}
                                            </pre>
                                        </li>
                                    ))}
                                </ul>
                            )}
                        </div>
                    </div>
                ) : (
                    <div className="space-y-2 text-sm overflow-y-auto max-h-[480px]">
                        <div className="text-text-secondary">Relationship</div>
                        <div className="text-text-primary font-medium">{String(selected.data.rel ?? '')}</div>
                        <div className="text-text-secondary mt-2">FindingId</div>
                        <div className="text-text-primary font-mono">{String(selected.data.findingId ?? '')}</div>
                        {selected.data.evidence ? (
                            <>
                                <div className="text-text-secondary mt-2">Evidence</div>
                                <pre className="text-xs bg-bg-tertiary border border-border-medium rounded-lg p-2 overflow-auto max-h-64 text-text-secondary">
                                    {JSON.stringify(selected.data.evidence, null, 2)}
                                </pre>
                            </>
                        ) : null}
                    </div>
                )}
            </div>
        </div>
    );
}

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import cytoscape, { type Core } from 'cytoscape';
import type { EntityGraph, NodeFindingRef } from '../lib/extractEntityGraph';
import { computeBrightness, type GraphFilterState } from '../lib/graphViz/applyGraphVisibility';
import { buildCyElements } from '../lib/graphViz/buildCyElements';
import { bundleEdgesForViz, enrichGraphForViz } from '../lib/graphViz/enrichGraphForViz';
import { GRAPH_VIZ_CONFIG } from '../lib/graphViz/graphVizConfig';

type Props = {
    graph: EntityGraph;
    isFullscreen?: boolean;
};

type CyNode = cytoscape.NodeSingular;

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

function debounce<T extends (...args: never[]) => void>(fn: T, ms: number): T {
    let t: ReturnType<typeof setTimeout> | undefined;
    return ((...args: never[]) => {
        if (t) clearTimeout(t);
        t = setTimeout(() => fn(...args), ms);
    }) as T;
}

function applyLod(cy: Core, threshold: number) {
    const z = cy.zoom();
    const deep = z >= threshold;
    cy.batch(() => {
        cy.nodes().forEach((n) => {
            if (n.data('isCompound')) {
                n.addClass('lod-label');
                return;
            }
            const hv = n.data('highValue') === true;
            if (deep || hv) n.addClass('lod-label');
            else n.removeClass('lod-label');
        });
        cy.edges().forEach((e) => {
            if (deep || e.hasClass('path-hit')) e.addClass('lod-label');
            else e.removeClass('lod-label');
        });
    });
}

function applyBrightness(
    cy: Core,
    nodeBright: Map<string, boolean>,
    edgeBright: Map<string, boolean>,
    pathEdges: Set<string>,
    domainKeysFilter: Set<string>
) {
    cy.batch(() => {
        cy.nodes().forEach((n) => {
            if (n.data('isCompound')) {
                const dk = String(n.data('domainKey') ?? 'unknown');
                const domOk = domainKeysFilter.size === 0 || domainKeysFilter.has(dk);
                n.toggleClass('faded', !domOk);
                return;
            }
            const id = n.id();
            n.toggleClass('faded', nodeBright.get(id) !== true);
        });
        cy.edges().forEach((e) => {
            const id = e.id();
            e.toggleClass('faded', edgeBright.get(id) !== true);
            e.toggleClass('path-hit', pathEdges.has(id));
        });
    });
}

function tierNudge(cy: Core, bandPx: number) {
    cy.batch(() => {
        cy.nodes().forEach((n) => {
            if (n.data('isCompound')) return;
            const t = Number(n.data('tier'));
            const tier = Number.isFinite(t) ? t : 3;
            const p = n.position();
            n.position({ x: p.x, y: p.y + tier * bandPx });
        });
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

    const [attackPathOnly, setAttackPathOnly] = useState(false);
    const [privilegedOnly, setPrivilegedOnly] = useState(false);
    const [kerberosOnly, setKerberosOnly] = useState(false);
    const [minDegree, setMinDegree] = useState(0);
    const [domainPick, setDomainPick] = useState<Set<string>>(() => new Set());
    const [bundleEdges, setBundleEdges] = useState(true);
    const [groupByDomain, setGroupByDomain] = useState(false);
    const [heatmapMode, setHeatmapMode] = useState(false);
    const [focusMode, setFocusMode] = useState(false);
    const [highlightPath, setHighlightPath] = useState(true);

    const findingsByNodeId = graph.findingsByNodeId ?? {};

    const enriched = useMemo(() => enrichGraphForViz(graph), [graph]);
    const bundled = useMemo(
        () => bundleEdgesForViz(enriched.edges, bundleEdges),
        [enriched.edges, bundleEdges]
    );

    const elements = useMemo(
        () =>
            buildCyElements(enriched.nodes, bundled, {
                groupByDomain,
                heatmapMode
            }),
        [enriched.nodes, bundled, groupByDomain, heatmapMode]
    );

    const filterState: GraphFilterState = useMemo(
        () => ({
            attackPathOnly,
            privilegedOnly,
            kerberosOnly,
            domainKeys: domainPick,
            minDegree,
            focusMode,
            highlightPathToTier0: highlightPath,
            focusNodeId: selected?.type === 'node' ? (selected.nodeId ?? null) : null
        }),
        [
            attackPathOnly,
            privilegedOnly,
            kerberosOnly,
            domainPick,
            minDegree,
            focusMode,
            highlightPath,
            selected
        ]
    );

    const brightness = useMemo(
        () => computeBrightness(enriched.nodes, bundled, filterState),
        [enriched.nodes, bundled, filterState]
    );

    const vizApplyRef = useRef({ brightness, domainKeys: filterState.domainKeys });
    vizApplyRef.current = { brightness, domainKeys: filterState.domainKeys };

    const layoutOpts = useMemo(() => {
        const n = graph.nodes.length;
        const base =
            n > GRAPH_VIZ_CONFIG.layout.largeGraphNodeThreshold
                ? GRAPH_VIZ_CONFIG.layout.coseLarge
                : GRAPH_VIZ_CONFIG.layout.cose;
        return { ...base } as cytoscape.LayoutOptions;
    }, [graph.nodes.length]);

    useEffect(() => {
        if (!containerRef.current) return;
        if (cyRef.current) {
            cyRef.current.destroy();
            cyRef.current = null;
        }

        const cy = cytoscape({
            container: containerRef.current,
            elements: elements as unknown as cytoscape.ElementDefinition[],
            minZoom: GRAPH_VIZ_CONFIG.viewport.minZoom,
            maxZoom: GRAPH_VIZ_CONFIG.viewport.maxZoom,
            wheelSensitivity: GRAPH_VIZ_CONFIG.viewport.wheelSensitivity,
            style: [
                {
                    selector: 'node',
                    style: {
                        color: '#f1f5f9',
                        'font-size': 11,
                        'font-weight': 600,
                        'text-wrap': 'wrap',
                        'text-max-width': '110px',
                        'text-valign': 'bottom',
                        'text-halign': 'center',
                        'text-margin-y': 5,
                        'min-zoomed-font-size': 5,
                        'text-outline-width': 2,
                        'text-outline-color': '#0b1220',
                        'background-color': (ele: CyNode) =>
                            String(ele.data('heatColor') ?? '#64748b'),
                        'border-width': 2,
                        'border-color': '#0f172a',
                        width: (ele: CyNode) =>
                            ele.data('kind') === 'Domain' || ele.data('isCompound') ? 56 : 36,
                        height: (ele: CyNode) =>
                            ele.data('kind') === 'Domain' || ele.data('isCompound') ? 56 : 36,
                        'overlay-opacity': 0,
                        label: ''
                    }
                },
                {
                    selector: 'node.lod-label',
                    style: {
                        label: 'data(label)'
                    }
                },
                {
                    selector: 'node.hover-label',
                    style: {
                        label: 'data(fullLabel)',
                        'text-max-width': '200px'
                    }
                },
                {
                    selector: 'node.domain-compound',
                    style: {
                        'background-color': '#1e293b',
                        'background-opacity': 0.35,
                        'border-width': 2,
                        'border-style': 'dashed',
                        'border-color': '#64748b',
                        'text-valign': 'top',
                        'text-margin-y': -6,
                        shape: 'roundrectangle',
                        width: 'label',
                        height: 'label',
                        padding: '18px',
                        'font-size': 10,
                        color: '#94a3b8'
                    }
                },
                {
                    selector: 'node.faded',
                    style: {
                        opacity: 0.07,
                        'text-opacity': 0.05
                    }
                },
                {
                    selector: 'edge',
                    style: {
                        width: 1.2,
                        opacity: (ele: cytoscape.EdgeSingular) =>
                            ele.data('isLowPriority') ? 0.18 : 0.42,
                        'curve-style': 'bezier',
                        'target-arrow-shape': 'triangle',
                        'arrow-scale': 0.8,
                        'line-color': '#94a3b8',
                        'target-arrow-color': '#94a3b8',
                        label: '',
                        'font-size': 9,
                        color: '#e2e8f0',
                        'text-background-color': '#0f172a',
                        'text-background-opacity': 0.9,
                        'text-background-padding': '3px',
                        'text-rotation': 'autorotate'
                    }
                },
                {
                    selector: 'edge.lod-label',
                    style: {
                        label: 'data(label)'
                    }
                },
                {
                    selector: 'edge.faded',
                    style: {
                        opacity: 0.04
                    }
                },
                {
                    selector: 'edge.path-hit',
                    style: {
                        width: 3.5,
                        opacity: 1,
                        'line-color': '#fb923c',
                        'target-arrow-color': '#fb923c',
                        'z-index': 999
                    }
                },
                {
                    selector: 'node:selected',
                    style: {
                        'border-width': 4,
                        'border-color': '#fb923c',
                        width: (ele: CyNode) => (ele.data('isCompound') ? 62 : 44),
                        height: (ele: CyNode) => (ele.data('isCompound') ? 62 : 44)
                    }
                },
                {
                    selector: 'edge:selected',
                    style: {
                        width: 2.8,
                        opacity: 1,
                        'line-color': '#fb923c',
                        'target-arrow-color': '#fb923c',
                        'z-index': 1000
                    }
                }
            ],
            layout: layoutOpts
        });

        const onZoomLod = debounce(() => {
            applyLod(cy, GRAPH_VIZ_CONFIG.labelZoomThreshold);
        }, GRAPH_VIZ_CONFIG.zoomLodDebounceMs);
        cy.on('zoom', onZoomLod);
        cy.on('mouseover', 'node', (evt) => {
            evt.target.addClass('hover-label');
            applyLod(cy, GRAPH_VIZ_CONFIG.labelZoomThreshold);
        });
        cy.on('mouseout', 'node', (evt) => {
            evt.target.removeClass('hover-label');
            applyLod(cy, GRAPH_VIZ_CONFIG.labelZoomThreshold);
        });

        cy.one('layoutstop', () => {
            tierNudge(cy, GRAPH_VIZ_CONFIG.tierBandNudgePx);
            cy.fit(undefined, 88);
            applyLod(cy, GRAPH_VIZ_CONFIG.labelZoomThreshold);
            const v = vizApplyRef.current;
            applyBrightness(
                cy,
                v.brightness.nodeBright,
                v.brightness.edgeBright,
                v.brightness.pathEdgeIds,
                v.domainKeys
            );
        });

        cy.on('tap', 'edge', (evt) => {
            setSelected({ type: 'edge', data: evt.target.data() });
        });
        cy.on('tap', 'node', (evt) => {
            const t = evt.target;
            if (t.data('isCompound')) return;
            const nodeId = t.id();
            setSelected({ type: 'node', nodeId, data: t.data() });
        });
        cy.on('tap', (evt) => {
            if (evt.target === cy) setSelected(null);
        });

        cyRef.current = cy;
        return () => {
            cy.destroy();
            cyRef.current = null;
        };
    }, [elements, layoutOpts]);

    useEffect(() => {
        const cy = cyRef.current;
        if (!cy) return;
        applyBrightness(
            cy,
            brightness.nodeBright,
            brightness.edgeBright,
            brightness.pathEdgeIds,
            filterState.domainKeys
        );
    }, [brightness, filterState.domainKeys]);

    useEffect(() => {
        const el = containerRef.current;
        const cy = cyRef.current;
        if (!el || !cy) return;
        const ro = new ResizeObserver(() => {
            requestAnimationFrame(() => {
                cy.resize();
                cy.fit(undefined, 88);
            });
        });
        ro.observe(el);
        const t = window.setTimeout(() => {
            cy.resize();
            cy.fit(undefined, 88);
        }, 140);
        return () => {
            ro.disconnect();
            window.clearTimeout(t);
        };
    }, [isFullscreen, elements]);

    const resetView = useCallback(() => {
        const cy = cyRef.current;
        if (!cy) return;
        cy.elements().removeClass('faded path-hit');
        setAttackPathOnly(false);
        setPrivilegedOnly(false);
        setKerberosOnly(false);
        setMinDegree(0);
        setDomainPick(new Set());
        setFocusMode(false);
        setSelected(null);
        cy.fit(undefined, 88);
        applyLod(cy, GRAPH_VIZ_CONFIG.labelZoomThreshold);
    }, []);

    const toggleDomain = (dk: string) => {
        setDomainPick((prev) => {
            const next = new Set(prev);
            if (next.has(dk)) next.delete(dk);
            else next.add(dk);
            return next;
        });
    };

    const nodeFindingsSorted = useMemo(() => {
        if (selected?.type !== 'node' || !selected.nodeId) return [];
        const raw = findingsByNodeId[selected.nodeId];
        if (!raw?.length) return [];
        return sortFindings(raw);
    }, [selected, findingsByNodeId]);

    const stats = `${graph.nodes.length} nodes · ${bundled.length} edges${
        bundleEdges && bundled.length < graph.edges.length
            ? ` (${graph.edges.length} raw)`
            : ''
    }`;

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
                <div className="border-b border-border-medium px-3 py-2 space-y-2 bg-bg-secondary/40">
                    <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-[11px] text-text-tertiary">
                        <span>{stats}</span>
                        <span className="hidden sm:inline">
                            LOD: labels at zoom ≥ {GRAPH_VIZ_CONFIG.labelZoomThreshold}; hover for
                            full name.
                        </span>
                        {heatmapMode ? (
                            <span className="hidden md:inline text-text-tertiary">
                                Heatmap: tier-0 red · high orange · med yellow · low blue · noise
                                grey
                            </span>
                        ) : null}
                    </div>
                    <div className="flex flex-wrap gap-x-3 gap-y-2 text-xs text-text-secondary">
                        <label className="inline-flex items-center gap-1.5 cursor-pointer">
                            <input
                                type="checkbox"
                                checked={attackPathOnly}
                                onChange={(e) => setAttackPathOnly(e.target.checked)}
                            />
                            Attack-path edges
                        </label>
                        <label className="inline-flex items-center gap-1.5 cursor-pointer">
                            <input
                                type="checkbox"
                                checked={privilegedOnly}
                                onChange={(e) => setPrivilegedOnly(e.target.checked)}
                            />
                            Privileged only
                        </label>
                        <label className="inline-flex items-center gap-1.5 cursor-pointer">
                            <input
                                type="checkbox"
                                checked={kerberosOnly}
                                onChange={(e) => setKerberosOnly(e.target.checked)}
                            />
                            Kerberos-related
                        </label>
                        <label className="inline-flex items-center gap-1.5 cursor-pointer">
                            <input
                                type="checkbox"
                                checked={bundleEdges}
                                onChange={(e) => setBundleEdges(e.target.checked)}
                            />
                            Bundle duplicate rels
                        </label>
                        <label className="inline-flex items-center gap-1.5 cursor-pointer">
                            <input
                                type="checkbox"
                                checked={groupByDomain}
                                onChange={(e) => setGroupByDomain(e.target.checked)}
                            />
                            Group by domain (compound)
                        </label>
                        <label className="inline-flex items-center gap-1.5 cursor-pointer">
                            <input
                                type="checkbox"
                                checked={heatmapMode}
                                onChange={(e) => setHeatmapMode(e.target.checked)}
                            />
                            Risk heatmap
                        </label>
                        <label className="inline-flex items-center gap-1.5 cursor-pointer">
                            <input
                                type="checkbox"
                                checked={focusMode}
                                onChange={(e) => setFocusMode(e.target.checked)}
                            />
                            Focus selection
                        </label>
                        <label className="inline-flex items-center gap-1.5 cursor-pointer">
                            <input
                                type="checkbox"
                                checked={highlightPath}
                                disabled={!focusMode}
                                onChange={(e) => setHighlightPath(e.target.checked)}
                            />
                            Path → Tier 0
                        </label>
                        <span className="inline-flex items-center gap-1">
                            <span className="text-text-tertiary">Min degree</span>
                            <select
                                className="bg-bg-tertiary border border-border-medium rounded px-1 py-0.5 text-text-primary"
                                value={minDegree}
                                onChange={(e) => setMinDegree(Number(e.target.value))}
                            >
                                {[0, 1, 2, 3, 5, 8].map((d) => (
                                    <option key={d} value={d}>
                                        {d}
                                    </option>
                                ))}
                            </select>
                        </span>
                        <button
                            type="button"
                            className="text-accent-orange hover:underline"
                            onClick={resetView}
                        >
                            Reset view
                        </button>
                    </div>
                    {enriched.domainKeys.length > 1 ? (
                        <div className="flex flex-wrap gap-1.5 items-center text-[11px]">
                            <span className="text-text-tertiary shrink-0">Domains (include):</span>
                            {enriched.domainKeys.map((dk) => (
                                <button
                                    key={dk}
                                    type="button"
                                    className={`px-2 py-0.5 rounded border ${
                                        domainPick.size === 0 || domainPick.has(dk)
                                            ? 'border-accent-orange/60 bg-accent-orange/10 text-text-primary'
                                            : 'border-border-medium text-text-tertiary line-through opacity-60'
                                    }`}
                                    onClick={() => toggleDomain(dk)}
                                >
                                    {dk === 'unknown' ? '(unknown DN)' : dk}
                                </button>
                            ))}
                            <span className="text-text-tertiary">
                                Empty selection = show all; click to restrict to a subset
                            </span>
                        </div>
                    ) : null}
                </div>
                <div
                    ref={containerRef}
                    className={
                        isFullscreen ? 'w-full h-[min(72vh,860px)]' : 'w-full h-[480px]'
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
                        Click a node or edge. Tier-0 (Domain / DC / admin groups) stays visible under
                        attack-path filters. Use Focus to isolate neighbors and optional shortest path
                        toward Tier 0.
                    </div>
                ) : selected.type === 'node' ? (
                    <div className="space-y-3 text-sm min-h-0 flex flex-col flex-1 overflow-hidden">
                        <div className="shrink-0 space-y-1">
                            <div className="text-text-secondary text-xs uppercase tracking-wide">
                                Entity
                            </div>
                            <div className="text-text-primary font-medium">
                                {String(selected.data.kind ?? '')}
                            </div>
                            <div className="text-text-primary font-mono text-xs break-words">
                                {String(selected.data.fullLabel ?? selected.data.label ?? '')}
                            </div>
                        </div>
                        <div className="border-t border-border-light pt-3 flex flex-col flex-1 min-h-0 overflow-hidden">
                            <div className="text-text-secondary text-xs uppercase tracking-wide mb-2 shrink-0">
                                Checks / findings affecting this entity
                            </div>
                            {nodeFindingsSorted.length === 0 ? (
                                <p className="text-text-tertiary text-xs">
                                    No finding rows indexed for this node (unsupported check type or
                                    no matching fields).
                                </p>
                            ) : (
                                <ul className="space-y-3 overflow-y-auto pr-1 flex-1">
                                    {nodeFindingsSorted.map((ref, idx) => (
                                        <li
                                            key={`${ref.checkId}-${idx}-${ref.edgeSummary ?? ''}`}
                                            className="rounded-lg border border-border-medium bg-bg-tertiary/50 p-2.5 text-xs"
                                        >
                                            <div className="flex flex-wrap gap-1.5 mb-2">
                                                <span className="font-mono font-semibold text-accent-orange">
                                                    {ref.checkId}
                                                </span>
                                                {ref.severity && (
                                                    <span className="px-1.5 py-0.5 rounded bg-bg-secondary text-text-secondary capitalize">
                                                        {ref.severity}
                                                    </span>
                                                )}
                                                {ref.edgeSummary && (
                                                    <span
                                                        className="text-text-tertiary truncate max-w-full"
                                                        title={ref.edgeSummary}
                                                    >
                                                        {ref.edgeSummary}
                                                    </span>
                                                )}
                                            </div>
                                            {ref.checkName && (
                                                <div className="text-text-primary font-medium mb-1">
                                                    {ref.checkName}
                                                </div>
                                            )}
                                            {ref.category && (
                                                <div className="text-text-tertiary mb-2">
                                                    {ref.category}
                                                </div>
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
                    <BundledEdgePanel data={selected.data} />
                )}
            </div>
        </div>
    );
}

function BundledEdgePanel({ data }: { data: Record<string, unknown> }) {
    const mids = String(data.memberIds ?? data.id ?? '');
    const ids = mids.includes('|') ? mids.split('|') : mids ? [mids] : [];
    const fids = String(data.memberFindingIds ?? '')
        .split('|')
        .filter(Boolean);

    return (
        <div className="space-y-2 text-sm overflow-y-auto max-h-[480px]">
            <div className="text-text-secondary">Relationship</div>
            <div className="text-text-primary font-medium">{String(data.rel ?? '')}</div>
            <div className="text-text-secondary mt-2">Bundle</div>
            <div className="text-text-primary font-mono text-xs">
                {Number(data.bundleCount) > 1
                    ? `${data.bundleCount} parallel edges (same rel)`
                    : 'Single edge'}
            </div>
            {ids.length > 1 ? (
                <div className="mt-2">
                    <div className="text-text-secondary text-xs mb-1">Underlying edge ids</div>
                    <ul className="font-mono text-[10px] text-text-tertiary space-y-0.5 max-h-32 overflow-y-auto">
                        {ids.map((id) => (
                            <li key={id}>{id}</li>
                        ))}
                    </ul>
                </div>
            ) : null}
            {fids.length ? (
                <div className="mt-2">
                    <div className="text-text-secondary text-xs mb-1">Finding IDs</div>
                    <div className="font-mono text-xs break-words">{fids.join(', ')}</div>
                </div>
            ) : (
                <>
                    <div className="text-text-secondary mt-2">FindingId</div>
                    <div className="text-text-primary font-mono">{String(data.findingId ?? '')}</div>
                </>
            )}
            {data.evidence ? (
                <>
                    <div className="text-text-secondary mt-2">Evidence</div>
                    <pre className="text-xs bg-bg-tertiary border border-border-medium rounded-lg p-2 overflow-auto max-h-64 text-text-secondary">
                        {JSON.stringify(data.evidence, null, 2)}
                    </pre>
                </>
            ) : null}
        </div>
    );
}

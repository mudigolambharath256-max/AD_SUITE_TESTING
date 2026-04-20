import type { BundledEdgeViz, EnrichedNodeViz } from './enrichGraphForViz';
import { kindBaseColor, riskHeatmapColor } from './enrichGraphForViz';

export type CytoscapeElement = Record<string, unknown>;

function compoundParentId(domainKey: string): string {
    const safe = domainKey.replace(/[^a-zA-Z0-9_-]/g, '_');
    return `__dom_${safe || 'default'}`;
}

export function buildCyElements(
    nodes: EnrichedNodeViz[],
    edges: BundledEdgeViz[],
    opts: {
        groupByDomain: boolean;
        heatmapMode: boolean;
    }
): CytoscapeElement[] {
    const domainKeys = [...new Set(nodes.map((n) => n.domainKey))];
    const useCompound = opts.groupByDomain && domainKeys.length >= 1;

    const parents: CytoscapeElement[] = [];
    const parentByDomain = new Map<string, string>();

    if (useCompound) {
        for (const dk of domainKeys) {
            const pid = compoundParentId(dk);
            parentByDomain.set(dk, pid);
            const count = nodes.filter((n) => n.domainKey === dk).length;
            parents.push({
                group: 'nodes',
                data: {
                    id: pid,
                    label: dk === 'unknown' ? `Unknown DN (${count})` : `${dk} (${count})`,
                    kind: 'Domain',
                    isCompound: true,
                    domainKey: dk,
                    labelShort: dk === 'unknown' ? 'DN?' : dk,
                    tier: 0,
                    highValue: true,
                    riskScore: 0,
                    privileged: false,
                    kerberosRelated: false,
                    heatColor: '#475569'
                },
                classes: 'domain-compound'
            });
        }
    }

    const cyNodes: CytoscapeElement[] = nodes.map((n) => {
        const fill = opts.heatmapMode ? riskHeatmapColor(n.riskScore, n.tier) : kindBaseColor(n.kind);
        const parent = useCompound ? parentByDomain.get(n.domainKey) : undefined;
        return {
            group: 'nodes',
            data: {
                id: n.id,
                label: n.labelShort,
                fullLabel: n.label,
                kind: n.kind,
                tier: n.tier,
                domainKey: n.domainKey,
                highValue: n.highValue,
                riskScore: n.riskScore,
                privileged: n.privileged,
                kerberosRelated: n.kerberosRelated,
                degree: n.degree,
                heatColor: fill,
                ...(parent ? { parent } : {})
            }
        };
    });

    const cyEdges: CytoscapeElement[] = edges.map((e) => {
        const cnt = e.memberIds.length;
        const label =
            cnt > 1 ? `${e.rel} ×${cnt}` : `${e.rel} · ${e.memberFindingIds[0] ?? ''}`;
        return {
            group: 'edges',
            data: {
                id: e.id,
                source: e.from,
                target: e.to,
                rel: e.rel,
                label,
                bundleCount: cnt,
                memberIds: e.memberIds.join('|'),
                memberFindingIds: e.memberFindingIds.join('|'),
                isAttackPath: e.isAttackPath,
                isKerberos: e.isKerberos,
                isLowPriority: e.isLowPriority
            }
        };
    });

    return [...parents, ...cyNodes, ...cyEdges];
}

import type { BundledEdgeViz, EnrichedNodeViz } from './enrichGraphForViz';
import {
    buildDirectedAdjacency,
    buildUndirectedAdjacency,
    collectTierZeroIds,
    neighborSet,
    shortestDirectedPathToGoals
} from './graphPaths';

export type GraphFilterState = {
    attackPathOnly: boolean;
    privilegedOnly: boolean;
    kerberosOnly: boolean;
    /** Empty = all domains */
    domainKeys: Set<string>;
    minDegree: number;
    focusMode: boolean;
    highlightPathToTier0: boolean;
    focusNodeId: string | null;
};

export type BrightnessMaps = {
    nodeBright: Map<string, boolean>;
    edgeBright: Map<string, boolean>;
    pathEdgeIds: Set<string>;
    pathNodeIds: Set<string>;
};

/**
 * Computes full-opacity (bright) vs faded elements. Does not mutate graph data.
 */
export function computeBrightness(
    nodes: EnrichedNodeViz[],
    edges: BundledEdgeViz[],
    f: GraphFilterState
): BrightnessMaps {
    const pathEdgeIds = new Set<string>();
    const pathNodeIds = new Set<string>();

    const nodeFilter = new Map<string, boolean>();
    for (const n of nodes) {
        let ok = true;
        if (f.domainKeys.size > 0 && !f.domainKeys.has(n.domainKey)) ok = false;
        if (f.minDegree > 0 && n.tier > 0 && n.degree < f.minDegree) ok = false;
        if (f.privilegedOnly && !n.privileged) ok = false;
        nodeFilter.set(n.id, ok);
    }

    const edgeFilter = new Map<string, boolean>();
    for (const e of edges) {
        let ok =
            nodeFilter.get(e.from) === true &&
            nodeFilter.get(e.to) === true &&
            (!f.attackPathOnly || e.isAttackPath) &&
            (!f.kerberosOnly || e.isKerberos);
        edgeFilter.set(e.id, ok);
    }

    if (f.kerberosOnly) {
        for (const n of nodes) {
            if (n.tier === 0) continue;
            if (n.kerberosRelated) continue;
            const touch = edges.some(
                (e) =>
                    e.isKerberos &&
                    edgeFilter.get(e.id) &&
                    (e.from === n.id || e.to === n.id)
            );
            if (!touch) nodeFilter.set(n.id, false);
        }
        for (const e of edges) {
            if (nodeFilter.get(e.from) !== true || nodeFilter.get(e.to) !== true) {
                edgeFilter.set(e.id, false);
            }
        }
    }

    if (f.attackPathOnly) {
        for (const n of nodes) {
            if (n.tier === 0) continue;
            const touch = edges.some(
                (e) =>
                    e.isAttackPath &&
                    edgeFilter.get(e.id) &&
                    (e.from === n.id || e.to === n.id)
            );
            if (!touch) nodeFilter.set(n.id, false);
        }
        for (const e of edges) {
            if (nodeFilter.get(e.from) !== true || nodeFilter.get(e.to) !== true) {
                edgeFilter.set(e.id, false);
            }
        }
    }

    const nodeBright = new Map(nodeFilter);
    const edgeBright = new Map(edgeFilter);

    if (f.focusMode && f.focusNodeId) {
        const undir = buildUndirectedAdjacency(edges);
        const keep = neighborSet(f.focusNodeId, undir);

        if (f.highlightPathToTier0) {
            const adj = buildDirectedAdjacency(edges);
            const goals = collectTierZeroIds(nodes);
            const path = shortestDirectedPathToGoals(adj, f.focusNodeId, goals);
            if (path) {
                for (const id of path.edgeIds) pathEdgeIds.add(id);
                for (const id of path.nodes) pathNodeIds.add(id);
            }
        }
        for (const id of pathNodeIds) keep.add(id);

        for (const n of nodes) {
            const base = nodeBright.get(n.id) === true;
            nodeBright.set(n.id, base && keep.has(n.id));
        }
        for (const e of edges) {
            const base = edgeBright.get(e.id) === true;
            const onPath = pathEdgeIds.has(e.id);
            const endsIn = keep.has(e.from) && keep.has(e.to);
            edgeBright.set(e.id, base && (onPath || endsIn));
        }
    }

    return { nodeBright, edgeBright, pathEdgeIds, pathNodeIds };
}

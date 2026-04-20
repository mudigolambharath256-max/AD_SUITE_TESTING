import type { BundledEdgeViz, EnrichedNodeViz } from './enrichGraphForViz';

/** Directed adjacency: source -> targets with edge ids for reconstruction. */
export function buildDirectedAdjacency(
    edges: BundledEdgeViz[]
): Map<string, Array<{ to: string; edgeId: string }>> {
    const adj = new Map<string, Array<{ to: string; edgeId: string }>>();
    for (const e of edges) {
        if (!adj.has(e.from)) adj.set(e.from, []);
        adj.get(e.from)!.push({ to: e.to, edgeId: e.id });
    }
    return adj;
}

/** Undirected adjacency for neighborhood / focus mode. */
export function buildUndirectedAdjacency(edges: BundledEdgeViz[]): Map<string, Set<string>> {
    const adj = new Map<string, Set<string>>();
    const add = (a: string, b: string) => {
        if (!adj.has(a)) adj.set(a, new Set());
        if (!adj.has(b)) adj.set(b, new Set());
        adj.get(a)!.add(b);
        adj.get(b)!.add(a);
    };
    for (const e of edges) {
        add(e.from, e.to);
    }
    return adj;
}

export function neighborSet(rootId: string, undirected: Map<string, Set<string>>): Set<string> {
    const n = new Set<string>([rootId]);
    const hop = undirected.get(rootId);
    if (hop) for (const x of hop) n.add(x);
    return n;
}

/**
 * BFS shortest path from start to any goal node; returns ordered node ids and edge ids on path.
 */
export function shortestDirectedPathToGoals(
    adj: Map<string, Array<{ to: string; edgeId: string }>>,
    start: string,
    goals: Set<string>
): { nodes: string[]; edgeIds: string[] } | null {
    if (goals.has(start)) return { nodes: [start], edgeIds: [] };
    const q: string[] = [start];
    const prev = new Map<string, { node: string; edgeId: string } | null>();
    prev.set(start, null);
    while (q.length) {
        const u = q.shift()!;
        const outs = adj.get(u);
        if (!outs) continue;
        for (const { to, edgeId } of outs) {
            if (prev.has(to)) continue;
            prev.set(to, { node: u, edgeId });
            if (goals.has(to)) {
                const nodePath: string[] = [to];
                const edgePath: string[] = [];
                let cur: string | undefined = to;
                while (cur && cur !== start) {
                    const p = prev.get(cur);
                    if (!p || p === null) break;
                    edgePath.push(p.edgeId);
                    nodePath.push(p.node);
                    cur = p.node;
                }
                nodePath.reverse();
                edgePath.reverse();
                return { nodes: nodePath, edgeIds: edgePath };
            }
            q.push(to);
        }
    }
    return null;
}

export function collectTierZeroIds(nodes: EnrichedNodeViz[]): Set<string> {
    const s = new Set<string>();
    for (const n of nodes) {
        if (n.tier === 0) s.add(n.id);
    }
    return s;
}

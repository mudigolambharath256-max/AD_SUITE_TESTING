import { extractDomainFromDn } from '../buildAdGraph';
import type { EntityGraph, EntityKind, GraphNode, NodeFindingRef } from '../extractEntityGraph';
import { GRAPH_VIZ_CONFIG } from './graphVizConfig';

export type VizTier = 0 | 1 | 2 | 3;

export interface EnrichedNodeViz {
    id: string;
    kind: EntityKind;
    label: string;
    dn?: string;
    tier: VizTier;
    domainKey: string;
    ouSegments: string[];
    riskScore: number;
    highValue: boolean;
    privileged: boolean;
    kerberosRelated: boolean;
    degree: number;
    maxSeverity: string;
    /** Short label for map; full in data panel. */
    labelShort: string;
}

export interface EnrichedEdgeViz {
    id: string;
    from: string;
    to: string;
    rel: string;
    findingId: string;
    evidence?: Record<string, unknown>;
    isAttackPath: boolean;
    isKerberos: boolean;
    isLowPriority: boolean;
    maxSeverityRank: number;
}

const ADMIN_GROUP_RE =
    /domain admins|enterprise admins|schema admins|dnsadmins|dns admins|key admins|enterprise key admins|account operators|backup operators|server operators|print operators|hyper-v admins|exchange trusted subsystem|organization management|administrators/i;

const DC_NAME_RE = /(^dc[\d-]?)|\bdc\d*\b|domain controller/i;

function domainKeyFromDn(dn?: string): string {
    return extractDomainFromDn(dn);
}

function ouSegmentsFromDn(dn?: string): string[] {
    if (!dn?.trim()) return [];
    const parts = dn.split(',').map((s) => s.trim());
    const ous: string[] = [];
    for (const p of parts) {
        if (p.toUpperCase().startsWith('OU=')) ous.push(p.slice(3));
    }
    return ous;
}

function sevToPoints(s: string | undefined): number {
    const x = (s || 'low').toLowerCase();
    if (x === 'critical' || x === 'crit') return 25;
    if (x === 'high') return 15;
    if (x === 'medium' || x === 'med') return 8;
    return 3;
}

function sevRank(s: string | undefined): number {
    const x = (s || 'low').toLowerCase();
    if (x === 'critical' || x === 'crit') return 0;
    if (x === 'high') return 1;
    if (x === 'medium' || x === 'med') return 2;
    return 3;
}

function riskScoreFromFindings(refs: NodeFindingRef[] | undefined): number {
    if (!refs?.length) return 0;
    let t = 0;
    for (const r of refs) t += sevToPoints(r.severity);
    return Math.min(100, t);
}

function findingKerberosHit(refs: NodeFindingRef[] | undefined): boolean {
    if (!refs?.length) return false;
    const re = /krb|kerberos|as-rep|asrep|tgt|spn|golden|silver|dcsync|delegation/i;
    for (const r of refs) {
        if (re.test(r.checkId)) return true;
        if (r.category && re.test(r.category)) return true;
        if (r.edgeSummary && re.test(r.edgeSummary)) return true;
    }
    return false;
}

function inferTier(n: GraphNode, risk: number, maxSev: string): VizTier {
    const label = n.label || '';
    if (n.kind === 'Domain') return 0;
    if (n.kind === 'Computer' && DC_NAME_RE.test(label)) return 0;
    if (n.kind === 'Group' && ADMIN_GROUP_RE.test(label)) return 0;
    if (n.kind === 'Group') return 1;
    if (risk >= 55 || sevRank(maxSev) <= 1) return 1;
    if (n.kind === 'User' || n.kind === 'Computer') return 2;
    return 3;
}

function truncateLabel(s: string, max: number): string {
    if (s.length <= max) return s;
    return `${s.slice(0, max - 1)}…`;
}

export function enrichGraphForViz(graph: EntityGraph): {
    nodes: EnrichedNodeViz[];
    edges: EnrichedEdgeViz[];
    domainKeys: string[];
} {
    const findingsByNodeId = graph.findingsByNodeId ?? {};
    const deg = new Map<string, number>();
    for (const e of graph.edges) {
        deg.set(e.from, (deg.get(e.from) ?? 0) + 1);
        deg.set(e.to, (deg.get(e.to) ?? 0) + 1);
    }

    const nodes: EnrichedNodeViz[] = graph.nodes.map((n) => {
        const refs = findingsByNodeId[n.id];
        const risk = riskScoreFromFindings(refs);
        const maxSev = (n.maxSeverity || refs?.[0]?.severity || 'low') as string;
        const tier = inferTier(n, risk, maxSev);
        const domainKey = domainKeyFromDn(n.dn);
        const krb = findingKerberosHit(refs);
        const privileged = tier <= 1 || risk >= 45 || ADMIN_GROUP_RE.test(n.label);
        const highValue = tier <= 1 || risk >= 40 || krb || n.kind === 'Domain';

        return {
            id: n.id,
            kind: n.kind,
            label: n.label,
            dn: n.dn,
            tier,
            domainKey,
            ouSegments: ouSegmentsFromDn(n.dn),
            riskScore: risk,
            highValue,
            privileged,
            kerberosRelated: krb,
            degree: deg.get(n.id) ?? 0,
            maxSeverity: maxSev,
            labelShort: truncateLabel(String(n.label ?? ''), 26)
        };
    });

    const edges: EnrichedEdgeViz[] = graph.edges.map((e) => {
        const relLower = e.rel.toLowerCase();
        const isAttack =
            GRAPH_VIZ_CONFIG.attackPathRels.has(relLower) ||
            GRAPH_VIZ_CONFIG.kerberosRels.has(relLower);
        const isKerb =
            GRAPH_VIZ_CONFIG.kerberosRels.has(relLower) || /krb|kerb|spn|as-rep|tgt/i.test(e.rel);
        const isLow = GRAPH_VIZ_CONFIG.lowPriorityRels.has(relLower);
        return {
            id: e.id,
            from: e.from,
            to: e.to,
            rel: e.rel,
            findingId: e.findingId,
            evidence: e.evidence,
            isAttackPath: isAttack,
            isKerberos: isKerb,
            isLowPriority: isLow,
            maxSeverityRank: 3
        };
    });

    const domainKeys = [...new Set(nodes.map((n) => n.domainKey))].sort();
    return { nodes, edges, domainKeys };
}

export interface BundledEdgeViz {
    id: string;
    from: string;
    to: string;
    rel: string;
    memberIds: string[];
    memberFindingIds: string[];
    isAttackPath: boolean;
    isKerberos: boolean;
    isLowPriority: boolean;
}

export function bundleEdgesForViz(edges: EnrichedEdgeViz[], enabled: boolean): BundledEdgeViz[] {
    if (!enabled) {
        return edges.map((e) => ({
            id: e.id,
            from: e.from,
            to: e.to,
            rel: e.rel,
            memberIds: [e.id],
            memberFindingIds: [e.findingId],
            isAttackPath: e.isAttackPath,
            isKerberos: e.isKerberos,
            isLowPriority: e.isLowPriority
        }));
    }
    const m = new Map<string, EnrichedEdgeViz[]>();
    for (const e of edges) {
        const k = `${e.from}\0${e.to}\0${e.rel}`;
        if (!m.has(k)) m.set(k, []);
        m.get(k)!.push(e);
    }
    const out: BundledEdgeViz[] = [];
    let i = 0;
    for (const group of m.values()) {
        const first = group[0];
        const isAttack = group.some((x) => x.isAttackPath);
        const isKerb = group.some((x) => x.isKerberos);
        const isLow = group.every((x) => x.isLowPriority);
        const id =
            group.length === 1
                ? first.id
                : `__bundle_${first.from.slice(0, 8)}_${first.to.slice(0, 8)}_${i++}`;
        out.push({
            id,
            from: first.from,
            to: first.to,
            rel: first.rel,
            memberIds: group.map((g) => g.id),
            memberFindingIds: group.map((g) => g.findingId),
            isAttackPath: isAttack,
            isKerberos: isKerb,
            isLowPriority: isLow
        });
    }
    return out;
}

/** Analyst color scale: red (critical) → orange → yellow → blue → grey. */
export function riskHeatmapColor(score: number, tier: VizTier): string {
    if (tier === 0) return '#dc2626';
    if (score >= 70) return '#ea580c';
    if (score >= 40) return '#ca8a04';
    if (score >= 15) return '#2563eb';
    return '#64748b';
}

export function kindBaseColor(kind: EntityKind): string {
    switch (kind) {
        case 'User':
            return '#3b82f6';
        case 'Computer':
            return '#22c55e';
        case 'Group':
            return '#eab308';
        case 'Domain':
            return '#f8fafc';
        default:
            return '#94a3b8';
    }
}

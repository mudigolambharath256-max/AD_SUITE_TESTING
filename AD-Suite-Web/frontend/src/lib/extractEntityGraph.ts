import { adGraphToEntityGraph, buildAdGraphFromFindings } from './buildAdGraph';

export type EntityKind =
    | 'User'
    | 'Computer'
    | 'Group'
    | 'Template'
    | 'CA'
    | 'GPO'
    | 'OU'
    | 'Domain'
    | 'Other';

export interface GraphNode {
    id: string;
    kind: EntityKind;
    label: string;
    /** Worst severity across linked checks (from graph builder). */
    maxSeverity?: string;
    /** Distinct check IDs touching this node. */
    risks?: string[];
    /** Distinguished name when the builder captured it (domain / OU hints). */
    dn?: string;
}

export interface GraphEdge {
    id: string;
    from: string;
    to: string;
    rel: string;
    findingId: string;
    evidence?: Record<string, unknown>;
}

/** Full finding row + metadata for the Selection panel when a node is clicked. */
export interface NodeFindingRef {
    checkId: string;
    checkName?: string;
    category?: string;
    severity?: string;
    /** Relationship label involving this entity (e.g. Kerberoast, DCSync). */
    edgeSummary?: string;
    /** Entire finding row (normalized / enriched). */
    fields: Record<string, unknown>;
}

export interface EntityGraph {
    nodes: GraphNode[];
    edges: GraphEdge[];
    /** Per graph node id: all checks/findings that reference this entity. */
    findingsByNodeId: Record<string, NodeFindingRef[]>;
}

/** Prefer standard fields; some exports use Risk / RiskLevel instead of Severity. */
export function effectiveFindingSeverity(f: Record<string, unknown>): unknown {
    return f.Severity ?? f.severity ?? f.Risk ?? f.risk ?? f.RiskLevel ?? f.riskLevel;
}

/**
 * Map engine/API severity strings to the four UI buckets (case-insensitive).
 * Informational/info map to Low so the four severity toggles still apply.
 */
export function canonicalSeverityForFilter(raw: unknown): 'Critical' | 'High' | 'Medium' | 'Low' {
    const s = String(raw ?? '')
        .trim()
        .toLowerCase();
    if (s === 'critical' || s === 'crit') return 'Critical';
    if (s === 'high') return 'High';
    if (s === 'medium' || s === 'med') return 'Medium';
    if (s === 'low') return 'Low';
    if (s === 'informational' || s === 'info') return 'Low';
    if (s === 'warning' || s === 'warn') return 'Medium';
    if (!s) return 'Low';
    return 'Low';
}

export type FlattenFindingRowsOptions = {
    /** When a check has no nested Findings[], still emit one row from the check object (Attack Path / LLM payloads). */
    includeParentWhenNoNestedFindings?: boolean;
};

/** Flatten scan results[] into individual finding rows; merge parent check metadata when missing on the row. */
export function flattenFindingRows(
    scanResults: unknown[],
    opts?: FlattenFindingRowsOptions
): Array<Record<string, unknown>> {
    const includeParent = opts?.includeParentWhenNoNestedFindings === true;
    const out: Array<Record<string, unknown>> = [];
    for (const r of scanResults as any[]) {
        if (!r || typeof r !== 'object') continue;
        const findings = (r?.Findings ?? r?.findings) as unknown;
        const parentRow = r as Record<string, unknown>;
        const parentCheckName = r?.CheckName ?? r?.checkName;
        const parentCheckId = r?.CheckId ?? r?.checkId;
        const parentCategory = r?.Category ?? r?.category;
        const parentSeverity = effectiveFindingSeverity(parentRow);
        if (Array.isArray(findings) && findings.length) {
            for (const row of findings) {
                if (row && typeof row === 'object') {
                    const o = { ...(row as Record<string, unknown>) };
                    if (!o.CheckId && !o.checkId && parentCheckId != null) o.CheckId = parentCheckId;
                    if (!o.CheckName && !o.checkName && parentCheckName != null) o.CheckName = parentCheckName;
                    if (!o.Category && !o.category && parentCategory != null) o.Category = parentCategory;
                    if (!o.Severity && !o.severity && parentSeverity != null && parentSeverity !== '') {
                        o.Severity = parentSeverity;
                    }
                    out.push(o);
                }
            }
        } else if (includeParent) {
            out.push({ ...(r as Record<string, unknown>) });
        }
    }
    return out;
}

/**
 * Strict evidence-based extractor. Only emits edges when required fields exist.
 * Deterministic graph from [buildAdGraph.ts](buildAdGraph.ts); delegates for one source of truth.
 */
export function extractEntityGraphFromFindings(
    findingRows: Array<Record<string, unknown>>,
    opts: { domainLabel?: string } = {}
): EntityGraph {
    const ad = buildAdGraphFromFindings(findingRows, { domainLabel: opts.domainLabel });
    return adGraphToEntityGraph(ad);
}

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

function stableId(kind: string, label: string): string {
    // Cytoscape IDs can be any string; keep it deterministic and short.
    const s = `${kind}:${label}`.toLowerCase();
    let h = 2166136261;
    for (let i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i);
        h = Math.imul(h, 16777619);
    }
    return `${kind}_${(h >>> 0).toString(36)}`;
}

function normStr(v: unknown): string | null {
    if (v === null || v === undefined) return null;
    const s = String(v).trim();
    return s ? s : null;
}

function inferKindFromTokenish(label: string): EntityKind {
    // Best-effort: real labels are used, but some data may be token-like.
    if (/^U\d{3,}$/i.test(label)) return 'User';
    if (/^C\d{3,}$/i.test(label)) return 'Computer';
    if (/^G\d{3,}$/i.test(label)) return 'Group';
    if (/^T\d{3,}$/i.test(label)) return 'Template';
    if (/^CA\d{3,}$/i.test(label)) return 'CA';
    if (/^GPO\d{3,}$/i.test(label)) return 'GPO';
    if (/^OU\d{3,}$/i.test(label)) return 'OU';
    return 'Other';
}

function addNode(
    nodes: Map<string, GraphNode>,
    kind: EntityKind,
    label: string
): string {
    const id = stableId(kind, label);
    if (!nodes.has(id)) nodes.set(id, { id, kind, label });
    return id;
}

function addEdge(
    edges: Map<string, GraphEdge>,
    from: string,
    to: string,
    rel: string,
    findingId: string,
    evidence?: Record<string, unknown>
): void {
    const base = `${from}->${rel}->${to}#${findingId}`;
    const id = stableId('E', base);
    if (!edges.has(id)) edges.set(id, { id, from, to, rel, findingId, evidence });
}

function stableJsonForDedupe(obj: Record<string, unknown>): string {
    const keys = Object.keys(obj).sort();
    const sorted: Record<string, unknown> = {};
    for (const k of keys) sorted[k] = obj[k];
    return JSON.stringify(sorted);
}

function registerNodeFinding(
    byNode: Map<string, NodeFindingRef[]>,
    dedupePerNode: Map<string, Set<string>>,
    nodeId: string,
    f: Record<string, unknown>,
    edgeSummary?: string
): void {
    const checkId = normStr(f.CheckId ?? f.checkId) || 'UNKNOWN';
    const fields = { ...f };
    const key = `${checkId}::${stableJsonForDedupe(fields)}`;
    if (!dedupePerNode.has(nodeId)) dedupePerNode.set(nodeId, new Set());
    const set = dedupePerNode.get(nodeId)!;
    if (set.has(key)) return;
    set.add(key);

    const ref: NodeFindingRef = {
        checkId,
        checkName: normStr(f.CheckName ?? f.checkName) ?? undefined,
        category: normStr(f.Category ?? f.category) ?? undefined,
        severity: normStr(f.Severity ?? f.severity) ?? undefined,
        edgeSummary,
        fields
    };
    if (!byNode.has(nodeId)) byNode.set(nodeId, []);
    byNode.get(nodeId)!.push(ref);
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
        const parentCheckName = r?.CheckName ?? r?.checkName;
        const parentCategory = r?.Category ?? r?.category;
        const parentSeverity = r?.Severity ?? r?.severity;
        if (Array.isArray(findings) && findings.length) {
            for (const row of findings) {
                if (row && typeof row === 'object') {
                    const o = { ...(row as Record<string, unknown>) };
                    if (!o.CheckName && !o.checkName && parentCheckName != null) o.CheckName = parentCheckName;
                    if (!o.Category && !o.category && parentCategory != null) o.Category = parentCategory;
                    if (!o.Severity && !o.severity && parentSeverity != null) o.Severity = parentSeverity;
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
 * Designed to approximate BloodHound-style entity graphs from findings.
 */
export function extractEntityGraphFromFindings(
    findingRows: Array<Record<string, unknown>>,
    opts: { domainLabel?: string } = {}
): EntityGraph {
    const nodes = new Map<string, GraphNode>();
    const edges = new Map<string, GraphEdge>();
    const findingsByNode = new Map<string, NodeFindingRef[]>();
    const dedupePerNode = new Map<string, Set<string>>();

    const domainLabel = opts.domainLabel || 'Domain';
    const domainId = addNode(nodes, 'Domain', domainLabel);
    const anyUserId = addNode(nodes, 'Other', 'AnyDomainUser');

    for (const f of findingRows) {
        const checkId = normStr(f.CheckId ?? f.checkId) || 'UNKNOWN';

        // ACC-039: RBCD — DelegationSetBy -> AllowedToAct -> TargetComputer
        if (checkId === 'ACC-039') {
            const setter = normStr(f.DelegationSetBy);
            const target = normStr(f.TargetComputer);
            if (setter && target) {
                const setterKind: EntityKind =
                    setter.includes('\\') || /^[A-Za-z0-9._-]+$/.test(setter)
                        ? 'User'
                        : inferKindFromTokenish(setter);
                const u = addNode(nodes, setterKind, setter);
                const c = addNode(nodes, 'Computer', target);
                addEdge(edges, u, c, 'AllowedToAct(RBCD)', checkId, {
                    DelegationSetBy: f.DelegationSetBy,
                    TargetComputer: f.TargetComputer
                });
                registerNodeFinding(findingsByNode, dedupePerNode, u, f, 'AllowedToAct(RBCD)');
                registerNodeFinding(findingsByNode, dedupePerNode, c, f, 'AllowedToAct(RBCD)');
            }
            continue;
        }

        // ACC-033: DCSync — Principal -> DCSync -> Domain
        if (checkId === 'ACC-033') {
            const principal = normStr(f.Principal);
            if (principal) {
                const pk: EntityKind =
                    principal.includes('\\') || /^[A-Za-z0-9._-]+$/.test(principal)
                        ? 'User'
                        : inferKindFromTokenish(principal);
                const p = addNode(nodes, pk, principal);
                addEdge(edges, p, domainId, 'DCSync', checkId, {
                    Principal: f.Principal,
                    Right: f.Right,
                    Object: f.Object
                });
                registerNodeFinding(findingsByNode, dedupePerNode, p, f, 'DCSync');
                registerNodeFinding(findingsByNode, dedupePerNode, domainId, f, 'DCSync');
            }
            continue;
        }

        // GPO-001: weak perms — Trustee -> Right -> GPO and optionally -> OU
        if (checkId === 'GPO-001') {
            const trustee = normStr(f.Trustee);
            const gpo = normStr(f.GpoName);
            const ou = normStr(f.LinkedOu);
            const right = normStr(f.Right) || 'Write';
            if (trustee && gpo) {
                const tKind: EntityKind =
                    trustee.includes('\\') ? 'Group' : inferKindFromTokenish(trustee);
                const t = addNode(nodes, tKind, trustee);
                const g = addNode(nodes, 'GPO', gpo);
                addEdge(edges, t, g, right, checkId, {
                    Trustee: f.Trustee,
                    Right: f.Right,
                    GpoName: f.GpoName
                });
                registerNodeFinding(findingsByNode, dedupePerNode, t, f, right);
                registerNodeFinding(findingsByNode, dedupePerNode, g, f, right);
                if (ou) {
                    const o = addNode(nodes, 'OU', ou);
                    addEdge(edges, g, o, 'LinkedTo', checkId, { LinkedOu: f.LinkedOu });
                    registerNodeFinding(findingsByNode, dedupePerNode, o, f, 'LinkedTo');
                }
            }
            continue;
        }

        // ADCS-ESC1: enroll — EnrollableBy -> Enroll -> Template; Template -> PublishedBy -> CA
        if (checkId === 'ADCS-ESC1') {
            const enrollBy = normStr(f.EnrollableBy);
            const tpl = normStr(f.Template);
            const ca = normStr(f.CaName);
            if (enrollBy && tpl) {
                const ek: EntityKind = enrollBy.includes('\\') ? 'Group' : inferKindFromTokenish(enrollBy);
                const g = addNode(nodes, ek, enrollBy);
                const t = addNode(nodes, 'Template', tpl);
                addEdge(edges, g, t, 'Enroll', checkId, {
                    EnrollableBy: f.EnrollableBy,
                    Template: f.Template
                });
                registerNodeFinding(findingsByNode, dedupePerNode, g, f, 'Enroll');
                registerNodeFinding(findingsByNode, dedupePerNode, t, f, 'Enroll');
                if (ca) {
                    const caId = addNode(nodes, 'CA', ca);
                    addEdge(edges, t, caId, 'PublishedBy', checkId, { CaName: f.CaName });
                    registerNodeFinding(findingsByNode, dedupePerNode, caId, f, 'PublishedBy');
                }
            }
            continue;
        }

        // ADCS-ESC4: template ACL — Trustee -> Right -> Template
        if (checkId === 'ADCS-ESC4') {
            const trustee = normStr(f.Trustee);
            const tpl = normStr(f.Template);
            const right = normStr(f.Right) || 'WriteDacl';
            if (trustee && tpl) {
                const tk: EntityKind = trustee.includes('\\') ? 'Group' : inferKindFromTokenish(trustee);
                const tr = addNode(nodes, tk, trustee);
                const t = addNode(nodes, 'Template', tpl);
                addEdge(edges, tr, t, right, checkId, {
                    Trustee: f.Trustee,
                    Right: f.Right,
                    Template: f.Template
                });
                registerNodeFinding(findingsByNode, dedupePerNode, tr, f, right);
                registerNodeFinding(findingsByNode, dedupePerNode, t, f, right);
            }
            continue;
        }

        // Optional: show service accounts as nodes (no edges) for kerberoast/asrep if present.
        // ACC-034: Kerberoast — AnyDomainUser -> Kerberoast -> ServiceAccount
        if (checkId === 'ACC-034') {
            const svc = normStr(f.SamAccountName);
            const spn = normStr(f.ServicePrincipalName);
            if (svc) {
                const svcId = addNode(nodes, 'User', svc);
                addEdge(edges, anyUserId, svcId, 'Kerberoast', checkId, {
                    SamAccountName: f.SamAccountName,
                    ServicePrincipalName: f.ServicePrincipalName
                });
                registerNodeFinding(findingsByNode, dedupePerNode, anyUserId, f, 'Kerberoast');
                registerNodeFinding(findingsByNode, dedupePerNode, svcId, f, 'Kerberoast');
                if (spn) {
                    const spnId = addNode(nodes, 'Other', spn);
                    addEdge(edges, svcId, spnId, 'HasSPN', checkId, { ServicePrincipalName: f.ServicePrincipalName });
                    registerNodeFinding(findingsByNode, dedupePerNode, spnId, f, 'HasSPN');
                }
            }
            continue;
        }

        // KRB-002: AS-REP roast — AnyDomainUser -> ASREPRoast -> User
        if (checkId === 'KRB-002') {
            const u = normStr(f.SamAccountName);
            if (u) {
                const uid = addNode(nodes, 'User', u);
                addEdge(edges, anyUserId, uid, 'ASREPRoast', checkId, {
                    SamAccountName: f.SamAccountName,
                    DistinguishedName: f.DistinguishedName
                });
                registerNodeFinding(findingsByNode, dedupePerNode, anyUserId, f, 'ASREPRoast');
                registerNodeFinding(findingsByNode, dedupePerNode, uid, f, 'ASREPRoast');
            }
            continue;
        }

        // ACC-001: adminCount=1 users — User -> ProtectedBy(AdminSDHolder) -> Domain
        if (checkId === 'ACC-001') {
            const u = normStr(f.SamAccountName);
            if (u) {
                const uid = addNode(nodes, 'User', u);
                addEdge(edges, uid, domainId, 'ProtectedUser(adminCount=1)', checkId, {
                    SamAccountName: f.SamAccountName,
                    DistinguishedName: f.DistinguishedName,
                    Reason: f.Reason
                });
                registerNodeFinding(findingsByNode, dedupePerNode, uid, f, 'ProtectedUser(adminCount=1)');
                registerNodeFinding(findingsByNode, dedupePerNode, domainId, f, 'ProtectedUser(adminCount=1)');
            }
            continue;
        }

        // ACC-037: Shadow credentials present — Domain -> HasShadowCredentials -> Account
        if (checkId === 'ACC-037') {
            const acct = normStr(f.Account ?? f.SamAccountName);
            if (acct) {
                const aid = addNode(nodes, 'User', acct);
                addEdge(edges, domainId, aid, 'HasShadowCredentials', checkId, {
                    Account: f.Account ?? f.SamAccountName
                });
                registerNodeFinding(findingsByNode, dedupePerNode, domainId, f, 'HasShadowCredentials');
                registerNodeFinding(findingsByNode, dedupePerNode, aid, f, 'HasShadowCredentials');
            }
            continue;
        }

        // ACC-026: Reversible encryption — Domain -> ReversibleEncryptionEnabled -> Account
        if (checkId === 'ACC-026') {
            const acct = normStr(f.SamAccountName);
            if (acct) {
                const aid = addNode(nodes, 'User', acct);
                addEdge(edges, domainId, aid, 'ReversibleEncryptionEnabled', checkId, {
                    SamAccountName: f.SamAccountName
                });
                registerNodeFinding(findingsByNode, dedupePerNode, domainId, f, 'ReversibleEncryptionEnabled');
                registerNodeFinding(findingsByNode, dedupePerNode, aid, f, 'ReversibleEncryptionEnabled');
            }
            continue;
        }
    }

    const findingsByNodeId: Record<string, NodeFindingRef[]> = {};
    for (const [id, refs] of findingsByNode) {
        findingsByNodeId[id] = refs;
    }

    return { nodes: [...nodes.values()], edges: [...edges.values()], findingsByNodeId };
}


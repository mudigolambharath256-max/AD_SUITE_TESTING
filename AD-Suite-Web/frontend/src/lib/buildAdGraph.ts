/**
 * Deterministic AD entity graph from flattened finding rows.
 * Single source for Cytoscape (Scans), Sigma (New Scan), and Attack Path graphSummary.
 */
import type { EntityGraph, EntityKind, GraphEdge, GraphNode, NodeFindingRef } from './extractEntityGraph';

function effectiveFindingSeverity(f: Record<string, unknown>): unknown {
    return f.Severity ?? f.severity ?? f.Risk ?? f.risk ?? f.RiskLevel ?? f.riskLevel;
}

const SEVERITY_RANK: Record<string, number> = {
    critical: 0,
    crit: 0,
    high: 1,
    medium: 2,
    med: 2,
    low: 3,
    info: 4,
    informational: 4
};

function severityRank(s: string): number {
    const k = (s || '').trim().toLowerCase();
    return SEVERITY_RANK[k] ?? 50;
}

function worseSeverity(a: string, b: string): string {
    return severityRank(a) <= severityRank(b) ? a : b;
}

function stableId(kind: string, label: string): string {
    const s = `${kind}:${label}`.toLowerCase();
    let h = 2166136261;
    for (let i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i);
        h = Math.imul(h, 16777619);
    }
    return `${kind}_${(h >>> 0).toString(36)}`;
}

export function normStr(v: unknown): string | null {
    if (v === null || v === undefined) return null;
    const s = String(v).trim();
    return s ? s : null;
}

/** First RDN CN= value from a distinguishedName (Active Directory). */
export function cnFromDn(dn: string): string | null {
    const m = /^CN=([^,]+)/i.exec(dn.trim());
    return m ? m[1].replace(/\\,/g, ',').trim() : null;
}

/** Extract DNS domain from a DN or defaultNamingContext (DC= parts). */
export function extractDomainFromDn(dn?: string | null): string {
    if (!dn || typeof dn !== 'string') return 'unknown';
    const parts = dn.match(/DC=([^,]+)/gi);
    if (!parts || parts.length === 0) return 'unknown';
    return parts.map(p => p.replace(/^DC=/i, '')).join('.').toLowerCase();
}

function inferKindFromTokenish(label: string): EntityKind {
    if (/^U\d{3,}$/i.test(label)) return 'User';
    if (/^C\d{3,}$/i.test(label)) return 'Computer';
    if (/^G\d{3,}$/i.test(label)) return 'Group';
    if (/^T\d{3,}$/i.test(label)) return 'Template';
    if (/^CA\d{3,}$/i.test(label)) return 'CA';
    if (/^GPO\d{3,}$/i.test(label)) return 'GPO';
    if (/^OU\d{3,}$/i.test(label)) return 'OU';
    return 'Other';
}

/** Canonical display id: prefer NETBIOS\sam, else objectGuid, else stable hash of type+label. */
export function makeNodeKey(kind: EntityKind, label: string, opts?: { objectGuid?: string | null; dn?: string | null }): string {
    const guid = normStr(opts?.objectGuid);
    if (guid) return stableId('guid', guid);
    const netbios = label.includes('\\') ? label : null;
    if (netbios) return stableId(kind, netbios.toLowerCase());
    return stableId(kind, label);
}

interface InternalNode {
    id: string;
    kind: EntityKind;
    label: string;
    dn?: string;
    risks: string[];
    maxSeverity: string;
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

function upsertInternalNode(
    nodes: Map<string, InternalNode>,
    kind: EntityKind,
    label: string,
    checkId: string,
    severity: string,
    dn?: string | null,
    objectGuid?: string | null
): string {
    const id = makeNodeKey(kind, label, { dn, objectGuid });
    const sev = normStr(severity) || 'low';
    if (nodes.has(id)) {
        const n = nodes.get(id)!;
        if (!n.risks.includes(checkId)) n.risks.push(checkId);
        n.maxSeverity = worseSeverity(n.maxSeverity, sev);
        if (dn && !n.dn) n.dn = dn;
        return id;
    }
    nodes.set(id, {
        id,
        kind,
        label,
        dn: dn ?? undefined,
        risks: [checkId],
        maxSeverity: sev
    });
    return id;
}

function addAnchorNode(nodes: Map<string, InternalNode>, kind: EntityKind, label: string): string {
    const id = makeNodeKey(kind, label, {});
    if (!nodes.has(id)) {
        nodes.set(id, {
            id,
            kind,
            label,
            risks: [],
            maxSeverity: 'info'
        });
    }
    return id;
}

function bumpRisk(nodes: Map<string, InternalNode>, id: string, checkId: string, severity: string): void {
    const n = nodes.get(id);
    if (!n) return;
    if (!n.risks.includes(checkId)) n.risks.push(checkId);
    n.maxSeverity = worseSeverity(n.maxSeverity, normStr(severity) || 'low');
}

function addEdge(
    edges: Map<string, GraphEdge & { severity: string }>,
    from: string,
    to: string,
    rel: string,
    findingId: string,
    severity: string,
    evidence?: Record<string, unknown>
): void {
    const base = `${from}->${rel}->${to}#${findingId}`;
    const id = stableId('E', base);
    if (!edges.has(id)) edges.set(id, { id, from, to, rel, findingId, severity, evidence });
}

/** Keys used for node-only fallback (aligned with backend ENTITY_KEYS + graph-specific fields). */
const FALLBACK_KEYS: Array<{ key: string; kind: EntityKind }> = [
    { key: 'SamAccountName', kind: 'User' },
    { key: 'samAccountName', kind: 'User' },
    { key: 'Account', kind: 'User' },
    { key: 'account', kind: 'User' },
    { key: 'User', kind: 'User' },
    { key: 'user', kind: 'User' },
    { key: 'Principal', kind: 'User' },
    { key: 'principal', kind: 'User' },
    { key: 'DelegationSetBy', kind: 'User' },
    { key: 'delegationSetBy', kind: 'User' },
    { key: 'Computer', kind: 'Computer' },
    { key: 'computer', kind: 'Computer' },
    { key: 'TargetComputer', kind: 'Computer' },
    { key: 'targetComputer', kind: 'Computer' },
    { key: 'DnsHostName', kind: 'Computer' },
    { key: 'dnsHostName', kind: 'Computer' },
    { key: 'Trustee', kind: 'Group' },
    { key: 'trustee', kind: 'Group' },
    { key: 'Group', kind: 'Group' },
    { key: 'group', kind: 'Group' },
    { key: 'EnrollableBy', kind: 'Group' },
    { key: 'enrollableBy', kind: 'Group' },
    { key: 'Template', kind: 'Template' },
    { key: 'template', kind: 'Template' },
    { key: 'CaName', kind: 'CA' },
    { key: 'caName', kind: 'CA' },
    { key: 'GpoName', kind: 'GPO' },
    { key: 'gpoName', kind: 'GPO' },
    { key: 'LinkedOu', kind: 'OU' },
    { key: 'linkedOu', kind: 'OU' },
    { key: 'ServicePrincipalName', kind: 'Other' },
    { key: 'servicePrincipalName', kind: 'Other' }
];

/** Returns distinct graph node ids touched on this row (for SameFinding star edges). */
function applyGenericNodeFallback(
    f: Record<string, unknown>,
    checkId: string,
    severity: string,
    nodes: Map<string, InternalNode>,
    findingsByNode: Map<string, NodeFindingRef[]>,
    dedupePerNode: Map<string, Set<string>>
): string[] {
    const touched: string[] = [];
    const dn = normStr(f.DistinguishedName ?? f.distinguishedName);
    const og = normStr(f.ObjectGuid ?? f.objectGuid);
    const seen = new Set<string>();
    for (const { key, kind } of FALLBACK_KEYS) {
        if (!Object.prototype.hasOwnProperty.call(f, key)) continue;
        const raw = normStr((f as Record<string, unknown>)[key]);
        if (!raw) continue;
        const id = upsertInternalNode(nodes, kind, raw, checkId, severity, dn, og);
        if (seen.has(id)) continue;
        seen.add(id);
        touched.push(id);
        registerNodeFinding(findingsByNode, dedupePerNode, id, f, undefined);
    }
    return touched;
}

/** Link entities that appear on the same finding row (does not imply AD membership). */
function addSameFindingStar(
    edges: Map<string, GraphEdge & { severity: string }>,
    nodeIds: string[],
    checkId: string,
    severity: string
): void {
    if (nodeIds.length < 2) return;
    const hub = nodeIds[0];
    for (let i = 1; i < nodeIds.length; i++) {
        addEdge(edges, hub, nodeIds[i], 'SameFinding', checkId, severity, { link: 'co-entity-row' });
    }
}

/** Connect nodes that have no incident edges to Domain so the graph is one component for layout. */
/**
 * User/Group → Group edges from memberOf (LDAP DN). Runs for every finding row that has the fields.
 */
function linkMemberOfEdges(
    f: Record<string, unknown>,
    checkId: string,
    severity: string,
    nodes: Map<string, InternalNode>,
    edges: Map<string, GraphEdge & { severity: string }>,
    findingsByNode: Map<string, NodeFindingRef[]>,
    dedupePerNode: Map<string, Set<string>>
): void {
    const fromLabel =
        normStr(f.samAccountName ?? f.SamAccountName) ??
        normStr(f.name ?? f.Name) ??
        normStr(f.Principal ?? f.principal);
    if (!fromLabel) return;

    const fromKind: EntityKind =
        normStr(f.samAccountName ?? f.SamAccountName) || normStr(f.Principal ?? f.principal)
            ? 'User'
            : 'Group';
    const rowDn = normStr(f.distinguishedName ?? f.DistinguishedName);
    const og = normStr(f.ObjectGuid ?? f.objectGuid);

    const rawMo = f.memberOf ?? f.MemberOf;
    const mos: unknown[] = Array.isArray(rawMo) ? rawMo : rawMo != null ? [rawMo] : [];
    if (mos.length === 0) return;

    const entityId = upsertInternalNode(nodes, fromKind, fromLabel, checkId, severity, rowDn, og);
    registerNodeFinding(findingsByNode, dedupePerNode, entityId, f, 'MemberOf');

    for (const m of mos) {
        const moDn = normStr(m);
        if (!moDn) continue;
        const gName = cnFromDn(moDn);
        if (!gName) continue;
        const gid = upsertInternalNode(nodes, 'Group', gName, checkId, severity);
        registerNodeFinding(findingsByNode, dedupePerNode, gid, f, 'MemberOf');
        addEdge(edges, entityId, gid, 'MemberOf', checkId, severity, { memberOf: moDn });
    }
}

function linkOrphansToDomain(
    nodes: Map<string, InternalNode>,
    edges: Map<string, GraphEdge & { severity: string }>,
    domainId: string,
    anyUserId: string
): void {
    const connected = new Set<string>();
    for (const e of edges.values()) {
        connected.add(e.from);
        connected.add(e.to);
    }
    for (const [id, n] of nodes) {
        if (id === domainId || id === anyUserId) continue;
        if (n.kind === 'Domain') continue;
        if (connected.has(id)) continue;
        const fid = n.risks[0] || 'FINDING';
        const sev = n.maxSeverity || 'info';
        addEdge(edges, id, domainId, 'InScope', fid, sev, { link: 'orphan-to-domain' });
        connected.add(id);
        connected.add(domainId);
    }
}

export interface AdGraphNode {
    id: string;
    kind: EntityKind;
    label: string;
    dn?: string;
    risks: string[];
    maxSeverity: string;
}

export interface AdGraphEdge {
    id: string;
    source: string;
    target: string;
    relation: string;
    checkId: string;
    severity: string;
    evidence?: Record<string, unknown>;
}

export interface AdGraph {
    nodes: AdGraphNode[];
    edges: AdGraphEdge[];
    findingsByNodeId: Record<string, NodeFindingRef[]>;
}

export interface BuildAdGraphOptions {
    domainLabel?: string;
    defaultNamingContext?: string; // Add scan metadata support
}

export function buildAdGraphFromFindings(
    findingRows: Array<Record<string, unknown>>,
    opts: BuildAdGraphOptions = {}
): AdGraph {
    const nodes = new Map<string, InternalNode>();
    const edges = new Map<string, GraphEdge & { severity: string }>();
    const findingsByNode = new Map<string, NodeFindingRef[]>();
    const dedupePerNode = new Map<string, Set<string>>();

    const domainLabel = opts.domainLabel || 'Domain';
    const domainId = addAnchorNode(nodes, 'Domain', domainLabel);
    const anyUserId = addAnchorNode(nodes, 'Other', 'AnyDomainUser');

    for (const f of findingRows) {
        const checkId = normStr(f.CheckId ?? f.checkId) || 'UNKNOWN';
        const sevRaw = effectiveFindingSeverity(f);
        const severity = normStr(sevRaw) || 'low';
        let handled = false;

        const ensureGraphNodeId = (kind: EntityKind, label: string, dn?: string | null, og?: string | null) => {
            const domainFromDn = extractDomainFromDn(dn) 
                              || extractDomainFromDn(opts.defaultNamingContext) 
                              || 'unknown';
            const finalDomainLabel = domainFromDn === 'unknown' ? domainLabel : domainFromDn;
            
            // Update domain node if we found a real domain
            if (domainFromDn !== 'unknown' && finalDomainLabel !== domainLabel) {
                const existingDomainNode = nodes.get(domainId);
                if (existingDomainNode && existingDomainNode.label === domainLabel) {
                    existingDomainNode.label = finalDomainLabel;
                }
            }
            
            return upsertInternalNode(nodes, kind, label, checkId, severity, dn, og);
        };

        if (checkId === 'ACC-039') {
            const setter = normStr(f.DelegationSetBy);
            const target = normStr(f.TargetComputer);
            if (setter && target) {
                handled = true;
                const setterKind: EntityKind =
                    setter.includes('\\') || /^[A-Za-z0-9._-]+$/.test(setter) ? 'User' : inferKindFromTokenish(setter);
                const dn = normStr(f.DistinguishedName ?? f.distinguishedName);
                const u = ensureGraphNodeId(setterKind, setter, dn);
                const c = ensureGraphNodeId('Computer', target);
                addEdge(edges, u, c, 'AllowedToAct(RBCD)', checkId, severity, {
                    DelegationSetBy: f.DelegationSetBy,
                    TargetComputer: f.TargetComputer
                });
                registerNodeFinding(findingsByNode, dedupePerNode, u, f, 'AllowedToAct(RBCD)');
                registerNodeFinding(findingsByNode, dedupePerNode, c, f, 'AllowedToAct(RBCD)');
            }
        } else if (checkId === 'ACC-033') {
            const principal = normStr(f.Principal);
            if (principal) {
                handled = true;
                const pk: EntityKind =
                    principal.includes('\\') || /^[A-Za-z0-9._-]+$/.test(principal)
                        ? 'User'
                        : inferKindFromTokenish(principal);
                const p = ensureGraphNodeId(pk, principal);
                addEdge(edges, p, domainId, 'DCSync', checkId, severity, {
                    Principal: f.Principal,
                    Right: f.Right,
                    Object: f.Object
                });
                bumpRisk(nodes, domainId, checkId, severity);
                registerNodeFinding(findingsByNode, dedupePerNode, p, f, 'DCSync');
                registerNodeFinding(findingsByNode, dedupePerNode, domainId, f, 'DCSync');
            }
        } else if (checkId === 'GPO-001') {
            const trustee = normStr(f.Trustee);
            const gpo = normStr(f.GpoName);
            const ou = normStr(f.LinkedOu);
            const right = normStr(f.Right) || 'Write';
            if (trustee && gpo) {
                handled = true;
                const tKind: EntityKind = trustee.includes('\\') ? 'Group' : inferKindFromTokenish(trustee);
                const t = ensureGraphNodeId(tKind, trustee);
                const g = ensureGraphNodeId('GPO', gpo);
                addEdge(edges, t, g, right, checkId, severity, {
                    Trustee: f.Trustee,
                    Right: f.Right,
                    GpoName: f.GpoName
                });
                registerNodeFinding(findingsByNode, dedupePerNode, t, f, right);
                registerNodeFinding(findingsByNode, dedupePerNode, g, f, right);
                if (ou) {
                    const o = ensureGraphNodeId('OU', ou);
                    addEdge(edges, g, o, 'LinkedTo', checkId, severity, { LinkedOu: f.LinkedOu });
                    registerNodeFinding(findingsByNode, dedupePerNode, o, f, 'LinkedTo');
                }
            }
        } else if (checkId === 'ADCS-ESC1') {
            const enrollBy = normStr(f.EnrollableBy);
            const tpl = normStr(f.Template);
            const ca = normStr(f.CaName);
            if (enrollBy && tpl) {
                handled = true;
                const ek: EntityKind = enrollBy.includes('\\') ? 'Group' : inferKindFromTokenish(enrollBy);
                const g = ensureGraphNodeId(ek, enrollBy);
                const t = ensureGraphNodeId('Template', tpl);
                addEdge(edges, g, t, 'Enroll', checkId, severity, {
                    EnrollableBy: f.EnrollableBy,
                    Template: f.Template
                });
                registerNodeFinding(findingsByNode, dedupePerNode, g, f, 'Enroll');
                registerNodeFinding(findingsByNode, dedupePerNode, t, f, 'Enroll');
                if (ca) {
                    const caId = ensureGraphNodeId('CA', ca);
                    addEdge(edges, t, caId, 'PublishedBy', checkId, severity, { CaName: f.CaName });
                    registerNodeFinding(findingsByNode, dedupePerNode, caId, f, 'PublishedBy');
                }
            }
        } else if (checkId === 'ADCS-ESC4') {
            const trustee = normStr(f.Trustee);
            const tpl = normStr(f.Template);
            const right = normStr(f.Right) || 'WriteDacl';
            if (trustee && tpl) {
                handled = true;
                const tk: EntityKind = trustee.includes('\\') ? 'Group' : inferKindFromTokenish(trustee);
                const tr = ensureGraphNodeId(tk, trustee);
                const t = ensureGraphNodeId('Template', tpl);
                addEdge(edges, tr, t, right, checkId, severity, {
                    Trustee: f.Trustee,
                    Right: f.Right,
                    Template: f.Template
                });
                registerNodeFinding(findingsByNode, dedupePerNode, tr, f, right);
                registerNodeFinding(findingsByNode, dedupePerNode, t, f, right);
            }
        } else if (checkId === 'ACC-034') {
            const svc = normStr(f.SamAccountName);
            const spn = normStr(f.ServicePrincipalName);
            if (svc) {
                handled = true;
                const svcId = ensureGraphNodeId('User', svc);
                bumpRisk(nodes, anyUserId, checkId, severity);
                addEdge(edges, anyUserId, svcId, 'Kerberoast', checkId, severity, {
                    SamAccountName: f.SamAccountName,
                    ServicePrincipalName: f.ServicePrincipalName
                });
                registerNodeFinding(findingsByNode, dedupePerNode, anyUserId, f, 'Kerberoast');
                registerNodeFinding(findingsByNode, dedupePerNode, svcId, f, 'Kerberoast');
                if (spn) {
                    const spnId = ensureGraphNodeId('Other', spn);
                    addEdge(edges, svcId, spnId, 'HasSPN', checkId, severity, {
                        ServicePrincipalName: f.ServicePrincipalName
                    });
                    registerNodeFinding(findingsByNode, dedupePerNode, spnId, f, 'HasSPN');
                }
            }
        } else if (checkId === 'KRB-002') {
            const u = normStr(f.SamAccountName);
            if (u) {
                handled = true;
                const uid = ensureGraphNodeId('User', u);
                bumpRisk(nodes, anyUserId, checkId, severity);
                addEdge(edges, anyUserId, uid, 'ASREPRoast', checkId, severity, {
                    SamAccountName: f.SamAccountName,
                    DistinguishedName: f.DistinguishedName
                });
                registerNodeFinding(findingsByNode, dedupePerNode, anyUserId, f, 'ASREPRoast');
                registerNodeFinding(findingsByNode, dedupePerNode, uid, f, 'ASREPRoast');
            }
        } else if (checkId === 'ACC-001') {
            const u = normStr(f.SamAccountName);
            if (u) {
                handled = true;
                const uid = ensureGraphNodeId('User', u);
                addEdge(edges, uid, domainId, 'ProtectedUser(adminCount=1)', checkId, severity, {
                    SamAccountName: f.SamAccountName,
                    DistinguishedName: f.DistinguishedName,
                    Reason: f.Reason
                });
                bumpRisk(nodes, domainId, checkId, severity);
                registerNodeFinding(findingsByNode, dedupePerNode, uid, f, 'ProtectedUser(adminCount=1)');
                registerNodeFinding(findingsByNode, dedupePerNode, domainId, f, 'ProtectedUser(adminCount=1)');
            }
        } else if (checkId === 'ACC-037') {
            const acct = normStr(f.Account ?? f.SamAccountName);
            if (acct) {
                handled = true;
                const aid = ensureGraphNodeId('User', acct);
                addEdge(edges, domainId, aid, 'HasShadowCredentials', checkId, severity, {
                    Account: f.Account ?? f.SamAccountName
                });
                bumpRisk(nodes, domainId, checkId, severity);
                registerNodeFinding(findingsByNode, dedupePerNode, domainId, f, 'HasShadowCredentials');
                registerNodeFinding(findingsByNode, dedupePerNode, aid, f, 'HasShadowCredentials');
            }
        } else if (checkId === 'ACC-026') {
            const acct = normStr(f.SamAccountName);
            if (acct) {
                handled = true;
                const aid = ensureGraphNodeId('User', acct);
                addEdge(edges, domainId, aid, 'ReversibleEncryptionEnabled', checkId, severity, {
                    SamAccountName: f.SamAccountName
                });
                bumpRisk(nodes, domainId, checkId, severity);
                registerNodeFinding(findingsByNode, dedupePerNode, domainId, f, 'ReversibleEncryptionEnabled');
                registerNodeFinding(findingsByNode, dedupePerNode, aid, f, 'ReversibleEncryptionEnabled');
            }
        }

        if (!handled) {
            const touched = applyGenericNodeFallback(f, checkId, severity, nodes, findingsByNode, dedupePerNode);
            addSameFindingStar(edges, touched, checkId, severity);
        }

        linkMemberOfEdges(f, checkId, severity, nodes, edges, findingsByNode, dedupePerNode);
    }

    linkOrphansToDomain(nodes, edges, domainId, anyUserId);

    const adNodes: AdGraphNode[] = [...nodes.values()].map((n) => ({
        id: n.id,
        kind: n.kind,
        label: n.label,
        dn: n.dn,
        risks: [...n.risks],
        maxSeverity: n.maxSeverity
    }));

    const adEdges: AdGraphEdge[] = [...edges.values()].map((e) => ({
        id: e.id,
        source: e.from,
        target: e.to,
        relation: e.rel,
        checkId: e.findingId,
        severity: e.severity,
        evidence: e.evidence
    }));

    const findingsByNodeId: Record<string, NodeFindingRef[]> = {};
    for (const [id, refs] of findingsByNode) {
        findingsByNodeId[id] = refs;
    }

    return { nodes: adNodes, edges: adEdges, findingsByNodeId };
}

/** Map AdGraph to legacy EntityGraph for ScanEntityGraph (Cytoscape). */
export function adGraphToEntityGraph(ad: AdGraph): EntityGraph {
    const graphNodes: GraphNode[] = ad.nodes.map((n) => ({
        id: n.id,
        kind: n.kind,
        label: n.label,
        maxSeverity: n.maxSeverity,
        risks: n.risks?.length ? [...n.risks] : undefined,
        dn: n.dn
    }));
    const graphEdges: GraphEdge[] = ad.edges.map((e) => ({
        id: e.id,
        from: e.source,
        to: e.target,
        rel: e.relation,
        findingId: e.checkId,
        evidence: e.evidence
    }));
    return {
        nodes: graphNodes,
        edges: graphEdges,
        findingsByNodeId: ad.findingsByNodeId
    };
}

const SIGMA_COLORS: Record<string, string> = {
    User: '#60a5fa',
    Computer: '#34d399',
    Group: '#fbbf24',
    Template: '#a78bfa',
    CA: '#f472b6',
    GPO: '#fb7185',
    OU: '#38bdf8',
    Domain: '#e2e8f0',
    Other: '#94a3b8'
};

export interface SigmaGraphData {
    nodes: {
        id: string;
        label: string;
        /** Initial hint; GraphVisualizer overwrites from type + degree. */
        color: string;
        size: number;
        type?: string;
        maxSeverity?: string;
    }[];
    edges: {
        id: string;
        source: string;
        target: string;
        label: string;
        relation: string;
        severity: string;
    }[];
}

export function toSigmaGraphData(ad: AdGraph): SigmaGraphData {
    return {
        nodes: ad.nodes.map((n) => ({
            id: n.id,
            label: n.label,
            color: SIGMA_COLORS[n.kind] ?? '#888888',
            size: 4 + Math.min(n.risks.length * 2, 24),
            type: n.kind,
            maxSeverity: n.maxSeverity
        })),
        edges: ad.edges.map((e, i) => ({
            id: e.id || `e_${i}`,
            source: e.source,
            target: e.target,
            label: `${e.relation} (${e.checkId})`,
            relation: e.relation,
            severity: e.severity
        }))
    };
}

export interface GraphSummaryPayload {
    nodes: Array<{ id: string; kind: string; label: string; risks: string[]; maxSeverity: string }>;
    edges: Array<{ source: string; target: string; relation: string; checkId: string; severity: string }>;
    stats: { nodeCount: number; edgeCount: number; truncated: boolean };
}

const DEFAULT_SUMMARY_MAX_NODES = 80;
const DEFAULT_SUMMARY_MAX_EDGES = 120;

/** Compact graph for LLM prompts (high-value nodes/edges first). */
export function buildGraphSummary(
    ad: AdGraph,
    opts?: { maxNodes?: number; maxEdges?: number }
): GraphSummaryPayload {
    const maxNodes = opts?.maxNodes ?? DEFAULT_SUMMARY_MAX_NODES;
    const maxEdges = opts?.maxEdges ?? DEFAULT_SUMMARY_MAX_EDGES;

    const sevOrder = (s: string) => severityRank(s);
    const sortedNodes = [...ad.nodes].sort((a, b) => {
        const dr = sevOrder(a.maxSeverity) - sevOrder(b.maxSeverity);
        if (dr !== 0) return dr;
        return b.risks.length - a.risks.length;
    });

    const nodeSet = new Set(sortedNodes.slice(0, maxNodes).map((n) => n.id));
    let edges = ad.edges.filter((e) => nodeSet.has(e.source) && nodeSet.has(e.target));
    edges.sort((a, b) => sevOrder(a.severity) - sevOrder(b.severity));
    const truncatedEdges = edges.length > maxEdges;
    edges = edges.slice(0, maxEdges);

    return {
        nodes: sortedNodes.slice(0, maxNodes).map((n) => ({
            id: n.id,
            kind: n.kind,
            label: n.label,
            risks: n.risks,
            maxSeverity: n.maxSeverity
        })),
        edges: edges.map((e) => ({
            source: e.source,
            target: e.target,
            relation: e.relation,
            checkId: e.checkId,
            severity: e.severity
        })),
        stats: {
            nodeCount: ad.nodes.length,
            edgeCount: ad.edges.length,
            truncated: truncatedEdges || ad.nodes.length > maxNodes
        }
    };
}

/** Deterministic Mermaid flowchart from graph summary (optional LLM-free diagram). */
export function graphSummaryToMermaid(summary: GraphSummaryPayload): string {
    const idFor = (raw: string, i: number) => {
        const safe = raw.replace(/[^a-zA-Z0-9_]/g, '_').slice(0, 24) || `N${i}`;
        return `n${i}_${safe}`;
    };
    const nodeIds = new Map<string, string>();
    summary.nodes.forEach((n, i) => {
        nodeIds.set(n.id, idFor(n.id, i));
    });
    const lines = ['flowchart TD'];
    summary.nodes.forEach((n) => {
        const mid = nodeIds.get(n.id)!;
        const lab = `${n.label}`.replace(/[[\]"']/g, ' ').slice(0, 60);
        lines.push(`  ${mid}["${lab}"]`);
    });
    summary.edges.forEach((e) => {
        const a = nodeIds.get(e.source);
        const b = nodeIds.get(e.target);
        if (!a || !b) return;
        const el = `${e.relation}`.replace(/[[\]|]/g, ' ').slice(0, 40);
        lines.push(`  ${a} -->|${el}| ${b}`);
    });
    return lines.join('\n');
}

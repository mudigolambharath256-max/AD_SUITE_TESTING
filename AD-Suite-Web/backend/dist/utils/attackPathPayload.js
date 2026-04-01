"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.severityRank = severityRank;
exports.buildAttackPathPayload = buildAttackPathPayload;
const findingRedact_1 = require("./findingRedact");
const SEVERITY_RANK = {
    critical: 0,
    high: 1,
    medium: 2,
    low: 3,
    info: 4,
    informational: 4
};
function severityRank(s) {
    const k = (s || '').trim().toLowerCase();
    return SEVERITY_RANK[k] ?? 99;
}
const ENTITY_KEYS = [
    'SamAccountName',
    'samAccountName',
    'Account',
    'account',
    'User',
    'user',
    'Computer',
    'computer',
    'TargetComputer',
    'targetComputer',
    'Principal',
    'principal',
    'Trustee',
    'trustee',
    'Group',
    'group',
    'Template',
    'template',
    'CaName',
    'caName',
    'ServicePrincipalName',
    'servicePrincipalName',
    'GpoName',
    'gpoName',
    'LinkedOu',
    'linkedOu'
];
function toEntityString(v) {
    if (v === null || v === undefined)
        return null;
    const s = String(v).trim();
    if (!s)
        return null;
    // keep entity hints compact for prompting
    if (s.length > 80)
        return s.slice(0, 80) + '…';
    return s;
}
function extractEntities(raw) {
    const evidence = {};
    const entities = [];
    for (const k of ENTITY_KEYS) {
        if (Object.prototype.hasOwnProperty.call(raw, k)) {
            const v = raw[k];
            const s = toEntityString(v);
            if (s) {
                entities.push(s);
                evidence[k] = v;
            }
        }
    }
    return { entities: Array.from(new Set(entities)).slice(0, 8), evidence };
}
function normalizeFinding(raw) {
    const sev = String(raw.Severity ?? raw.severity ?? 'Unknown').trim() || 'Unknown';
    const cat = String(raw.Category ?? raw.category ?? 'Unknown').trim() || 'Unknown';
    const { entities, evidence } = extractEntities(raw);
    return {
        CheckId: String(raw.CheckId ?? raw.checkId ?? '').trim() || 'UNKNOWN',
        CheckName: String(raw.CheckName ?? raw.checkName ?? '').trim() || 'Unknown check',
        Severity: sev,
        Category: cat,
        Description: String(raw.Description ?? raw.Name ?? '').trim(),
        Impact: String(raw.Impact ?? raw.RiskData ?? raw.Message ?? '').trim(),
        Entities: entities.length ? entities : undefined,
        Evidence: Object.keys(evidence).length ? evidence : undefined
    };
}
function snippetKey(f) {
    const blob = `${f.Description}|${f.Impact}`.replace(/\s+/g, ' ').trim().slice(0, 120);
    return blob || '_empty';
}
function groupKey(f) {
    return `${f.CheckId}::${snippetKey(f)}`;
}
const DEFAULT_OPTS = {
    maxGroups: 140,
    maxSamplesPerGroup: 8,
    highVolumeThreshold: 25,
    maxChars: 48000
};
function buildAttackPathPayload(rawFindings, opts = {}) {
    const o = { ...DEFAULT_OPTS, ...opts };
    const rawInputCount = rawFindings.length;
    const normalized = rawFindings.map((r) => (0, findingRedact_1.redactFindingFields)(normalizeFinding(r)));
    const bySeverity = {};
    const byCategory = {};
    const byCheckId = new Map();
    for (const f of normalized) {
        const sev = f.Severity || 'Unknown';
        const cat = f.Category || 'Unknown';
        bySeverity[sev] = (bySeverity[sev] || 0) + 1;
        byCategory[cat] = (byCategory[cat] || 0) + 1;
        byCheckId.set(f.CheckId, (byCheckId.get(f.CheckId) || 0) + 1);
    }
    const topChecksByVolume = [...byCheckId.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 15)
        .map(([checkId, count]) => ({ checkId, count }));
    const buckets = new Map();
    for (const f of normalized) {
        const k = groupKey(f);
        if (!buckets.has(k))
            buckets.set(k, []);
        buckets.get(k).push(f);
    }
    const distinctGroups = buckets.size;
    const sortedGroupKeys = [...buckets.keys()].sort((ka, kb) => {
        const fa = buckets.get(ka)[0];
        const fb = buckets.get(kb)[0];
        const ra = severityRank(fa.Severity);
        const rb = severityRank(fb.Severity);
        if (ra !== rb)
            return ra - rb;
        return (buckets.get(kb).length - buckets.get(ka).length);
    });
    let groupedFindings = [];
    for (const gk of sortedGroupKeys) {
        const rows = buckets.get(gk);
        rows.sort((a, b) => severityRank(a.Severity) - severityRank(b.Severity));
        const first = rows[0];
        const n = rows.length;
        const take = n >= o.highVolumeThreshold ? o.maxSamplesPerGroup : Math.min(n, o.maxSamplesPerGroup);
        groupedFindings.push({
            groupKey: gk,
            checkId: first.CheckId,
            checkName: first.CheckName,
            severity: first.Severity,
            category: first.Category,
            occurrenceCount: n,
            samples: rows.slice(0, take)
        });
    }
    /** Raw rows that shared a group key with at least one other row (dedupe benefit). */
    const groupsCollapsed = Math.max(0, rawInputCount - distinctGroups);
    let truncatedToBudget = false;
    if (groupedFindings.length > o.maxGroups) {
        groupedFindings = groupedFindings.slice(0, o.maxGroups);
        truncatedToBudget = true;
    }
    const payload = {
        summary: {
            totalFindings: rawInputCount,
            bySeverity,
            byCategory,
            topChecksByVolume
        },
        groupedFindings
    };
    let userPromptJson = JSON.stringify(payload, null, 2);
    while (userPromptJson.length > o.maxChars && payload.groupedFindings.length > 1) {
        payload.groupedFindings = payload.groupedFindings.slice(0, Math.max(1, payload.groupedFindings.length - 1));
        userPromptJson = JSON.stringify(payload, null, 2);
        truncatedToBudget = true;
    }
    if (userPromptJson.length > o.maxChars && payload.groupedFindings.length === 1) {
        const g = payload.groupedFindings[0];
        if (g.samples.length > 1) {
            g.samples = g.samples.slice(0, Math.max(1, g.samples.length - 1));
            userPromptJson = JSON.stringify(payload, null, 2);
            truncatedToBudget = true;
        }
    }
    groupedFindings = payload.groupedFindings;
    const payloadRows = groupedFindings.reduce((acc, g) => acc + g.samples.length, 0);
    return {
        payload,
        userPromptJson,
        stats: {
            rawInputCount,
            distinctGroups,
            groupsCollapsed,
            payloadRows,
            approxChars: userPromptJson.length,
            truncatedToBudget
        }
    };
}
//# sourceMappingURL=attackPathPayload.js.map
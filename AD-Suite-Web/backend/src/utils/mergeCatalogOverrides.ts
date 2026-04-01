/**
 * Same merge semantics as Merge-ADSuiteCatalogOverrides in Modules/ADSuite.Adsi.psm1:
 * patch base checks by id; unknown override ids are ignored.
 */
export function mergeCatalogOverrides(baseDoc: { checks?: unknown[] }, overridesDoc: { checks?: unknown[] }): {
    checks?: unknown[];
} {
    if (!baseDoc || !Array.isArray(baseDoc.checks)) {
        return baseDoc;
    }
    if (!overridesDoc?.checks || !Array.isArray(overridesDoc.checks)) {
        return baseDoc;
    }
    const byId = new Map<string, Record<string, unknown>>();
    for (const c of baseDoc.checks) {
        if (c && typeof c === 'object' && 'id' in c && (c as { id: unknown }).id != null) {
            byId.set(String((c as { id: unknown }).id), c as Record<string, unknown>);
        }
    }
    for (const ov of overridesDoc.checks) {
        if (!ov || typeof ov !== 'object' || !('id' in ov) || ov.id == null) {
            continue;
        }
        const id = String((ov as { id: unknown }).id);
        const row = byId.get(id);
        if (!row) {
            continue;
        }
        for (const [k, v] of Object.entries(ov as Record<string, unknown>)) {
            if (k === 'id') {
                continue;
            }
            row[k] = v;
        }
    }
    return baseDoc;
}

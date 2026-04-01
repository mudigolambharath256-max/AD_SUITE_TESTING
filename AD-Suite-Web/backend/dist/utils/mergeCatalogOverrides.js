"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.mergeCatalogOverrides = mergeCatalogOverrides;
/**
 * Same merge semantics as Merge-ADSuiteCatalogOverrides in Modules/ADSuite.Adsi.psm1:
 * patch base checks by id; unknown override ids are ignored.
 */
function mergeCatalogOverrides(baseDoc, overridesDoc) {
    if (!baseDoc || !Array.isArray(baseDoc.checks)) {
        return baseDoc;
    }
    if (!overridesDoc?.checks || !Array.isArray(overridesDoc.checks)) {
        return baseDoc;
    }
    const byId = new Map();
    for (const c of baseDoc.checks) {
        if (c && typeof c === 'object' && 'id' in c && c.id != null) {
            byId.set(String(c.id), c);
        }
    }
    for (const ov of overridesDoc.checks) {
        if (!ov || typeof ov !== 'object' || !('id' in ov) || ov.id == null) {
            continue;
        }
        const id = String(ov.id);
        const row = byId.get(id);
        if (!row) {
            continue;
        }
        for (const [k, v] of Object.entries(ov)) {
            if (k === 'id') {
                continue;
            }
            row[k] = v;
        }
    }
    return baseDoc;
}
//# sourceMappingURL=mergeCatalogOverrides.js.map
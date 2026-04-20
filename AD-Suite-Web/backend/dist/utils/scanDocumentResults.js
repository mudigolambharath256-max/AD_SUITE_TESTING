"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.extractResultsArrayFromScanDocument = extractResultsArrayFromScanDocument;
/**
 * Extract the per-check results array from an AD Suite scan-results JSON document.
 * Must stay aligned with frontend `extractScanResultsArray` and docs/SCAN_RESULTS_FINDINGS_SCHEMA.md.
 */
function extractResultsArrayFromScanDocument(doc) {
    if (doc == null)
        return [];
    if (Array.isArray(doc))
        return doc;
    if (typeof doc !== 'object')
        return [];
    const d = doc;
    const r = d.results ?? d.Results ?? d.checks ?? d.Checks;
    if (Array.isArray(r))
        return r;
    if (r && typeof r === 'object' && Array.isArray(r.checks)) {
        return r.checks;
    }
    return [];
}
//# sourceMappingURL=scanDocumentResults.js.map
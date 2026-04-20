/**
 * Extract the per-check results array from an AD Suite scan-results JSON document.
 * Must stay aligned with frontend `extractScanResultsArray` and docs/SCAN_RESULTS_FINDINGS_SCHEMA.md.
 */
export function extractResultsArrayFromScanDocument(doc: unknown): unknown[] {
    if (doc == null) return [];
    if (Array.isArray(doc)) return doc;
    if (typeof doc !== 'object') return [];
    const d = doc as Record<string, unknown>;
    const r = d.results ?? d.Results ?? d.checks ?? d.Checks;
    if (Array.isArray(r)) return r;
    if (r && typeof r === 'object' && Array.isArray((r as { checks?: unknown[] }).checks)) {
        return (r as { checks: unknown[] }).checks;
    }
    return [];
}

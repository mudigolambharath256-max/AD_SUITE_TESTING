import { flattenFindingRows, type FlattenFindingRowsOptions } from './extractEntityGraph';

/**
 * Extract the per-check results array from a scan-results JSON document (or pass through if already an array).
 * Aligned with backend `extractResultsArrayFromScanDocument` and docs/SCAN_RESULTS_FINDINGS_SCHEMA.md.
 */
export function extractScanResultsArray(input: unknown): unknown[] {
    if (input == null) return [];
    if (Array.isArray(input)) return input;
    if (typeof input !== 'object') return [];
    const d = input as Record<string, unknown>;
    const r = d.results ?? d.Results ?? d.checks ?? d.Checks;
    if (Array.isArray(r)) return r;
    if (r && typeof r === 'object' && Array.isArray((r as { checks?: unknown[] }).checks)) {
        return (r as { checks: unknown[] }).checks;
    }
    return [];
}

/** Full document or results[] → flat finding rows for Attack Path, exports, etc. */
export function flattenDocumentToFindingRows(
    input: unknown,
    opts?: FlattenFindingRowsOptions
): Array<Record<string, unknown>> {
    return flattenFindingRows(extractScanResultsArray(input), opts);
}

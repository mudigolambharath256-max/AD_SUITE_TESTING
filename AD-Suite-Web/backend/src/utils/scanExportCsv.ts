import { extractResultsArrayFromScanDocument } from './scanDocumentResults';

/** Flatten per-check findings from scan-results.json into CSV text. */
export function findingsToCsv(doc: any): string {
    const results = extractResultsArrayFromScanDocument(doc);
    const rows: Record<string, unknown>[] = [];
    for (const r of results) {
        const check = r as Record<string, unknown>;
        const findings = (check.Findings ?? check.findings ?? []) as unknown[];
        for (const f of findings) {
            rows.push({
                CheckId: check.CheckId ?? check.checkId,
                CheckName: check.CheckName ?? check.checkName,
                Category: check.Category ?? check.category,
                Severity: check.Severity ?? check.severity,
                ...(typeof f === 'object' && f !== null ? f : {})
            });
        }
    }
    if (rows.length === 0) {
        return 'CheckId,CheckName,Category,Severity\n';
    }
    const keySet = new Set<string>();
    rows.forEach((row) => {
        Object.keys(row).forEach((k) => keySet.add(k));
    });
    const keys = Array.from(keySet);
    const esc = (v: unknown) => {
        const s = v == null ? '' : String(v);
        if (s.includes(',') || s.includes('"') || s.includes('\n')) {
            return `"${s.replace(/"/g, '""')}"`;
        }
        return s;
    };
    const lines = [keys.join(',')];
    rows.forEach((row) => {
        lines.push(keys.map((k) => esc((row as any)[k])).join(','));
    });
    return lines.join('\n');
}

"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.findingsToCsv = findingsToCsv;
/** Flatten per-check findings from scan-results.json into CSV text. */
function findingsToCsv(doc) {
    const results = doc.results || doc.Results || [];
    const rows = [];
    for (const r of results) {
        const findings = r.Findings || r.findings || [];
        for (const f of findings) {
            rows.push({
                CheckId: r.CheckId ?? r.checkId,
                CheckName: r.CheckName ?? r.checkName,
                Category: r.Category ?? r.category,
                Severity: r.Severity ?? r.severity,
                ...(typeof f === 'object' && f !== null ? f : {})
            });
        }
    }
    if (rows.length === 0) {
        return 'CheckId,CheckName,Category,Severity\n';
    }
    const keySet = new Set();
    rows.forEach((row) => {
        Object.keys(row).forEach((k) => keySet.add(k));
    });
    const keys = Array.from(keySet);
    const esc = (v) => {
        const s = v == null ? '' : String(v);
        if (s.includes(',') || s.includes('"') || s.includes('\n')) {
            return `"${s.replace(/"/g, '""')}"`;
        }
        return s;
    };
    const lines = [keys.join(',')];
    rows.forEach((row) => {
        lines.push(keys.map((k) => esc(row[k])).join(','));
    });
    return lines.join('\n');
}
//# sourceMappingURL=scanExportCsv.js.map